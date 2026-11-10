"""Turn processing for skeleton-mode stories.

A turn: the reader picks one of the offered choices -> its events apply -> the
next beat card is found (the next planned scene, or the next major event) ->
its brief is built from the state -> the scene is written and streamed ->
the scene, the new state and the beat are saved together.

Choices only change the state through their events, and the prose never does.
When a major event's scene has been written, the segment after it is planned in
the background while the reader reads.

The state before each turn is kept on the beat it produced (card.state_before),
so undoing a turn restores it exactly.
"""

import copy
import logging
import uuid
from dataclasses import dataclass, field
from datetime import timedelta
from typing import Any, AsyncIterator, Dict, List, Optional, Set

from app.services.scene_service import persist_chat_turn
from app.services.story_generation import (
    MAX_SEGMENT_TRIES,
    Job,
    LeaseLost,
    Planner,
    default_planner,
    fetch_plan,
    load_story,
    now_utc,
    parse_timestamp,
    problem_lines,
    spine_event_card,
)
from app.services.story_planner import plan_segment, scene_prompt
from app.services.story_skeleton import (
    brief_callbacks,
    build_brief,
    offer_choices,
    scene_cast,
    walk_cards,
    walk_spine,
)
from app.services.story_state import EventRejected, State, apply_event

logger = logging.getLogger(__name__)

WANTED_CHOICES = 3
PREVIOUS_TAIL_CHARS = 400  # end of the previous scene, so the prose carries on in the same voice
PLANNING_BACKOFF_SECONDS = 60  # after a failed segment plan, wait before trying again

_planning_story_ids: Set[str] = set()


class PlayError(Exception):
    def __init__(self, status_code: int, message: str):
        super().__init__(message)
        self.status_code = status_code
        self.message = message


# ---------- reading a story ----------


@dataclass
class PlayContext:
    story: Dict[str, Any]
    plan: Dict[str, Any]
    beats: List[Dict[str, Any]]  # sorted by seq

    @property
    def world(self) -> Dict[str, Any]:
        return {**self.plan["world"], "spine": self.plan["spine"]["events"]}

    @property
    def facts(self) -> List[str]:
        return self.plan["world"].get("facts") or []

    @property
    def state(self) -> State:
        return self.story["world_state"]

    @property
    def current(self) -> Dict[str, Any]:
        return next(beat for beat in self.beats if beat["seq"] == self.story.get("current_beat_seq"))


def load_context(client: Any, story_id: str) -> PlayContext:
    story = load_story(client, story_id)
    if not story:
        raise PlayError(404, "이야기를 찾을 수 없습니다.")
    if story.get("mode") != "skeleton":
        raise PlayError(409, "이 이야기는 선택지로 진행하지 않습니다.")
    plan = fetch_plan(client, story_id)
    if not plan or plan.get("status") != "ready" or story.get("status") not in ("active", "completed"):
        raise PlayError(409, "이야기를 아직 만들고 있습니다.")
    beats = client.table("story_beats").select("*").eq("story_id", story_id).execute().data or []
    return PlayContext(story, plan, sorted(beats, key=lambda beat: beat["seq"]))


def spine_index(context: PlayContext, event_id: Optional[str]) -> int:
    return next(index for index, event in enumerate(context.world["spine"]) if event["id"] == event_id)


def last_spine_index(context: PlayContext, up_to_seq: int) -> int:
    """Index of the latest major event the reader has reached."""
    reached = [beat for beat in context.beats if beat["spine_event_id"] and beat["seq"] <= up_to_seq]
    return spine_index(context, reached[-1]["spine_event_id"])


def planned_cards_after(context: PlayContext, seq: int) -> List[Dict[str, Any]]:
    """The planned scene cards after a beat, up to the next major event."""
    cards = []
    for beat in context.beats:
        if beat["seq"] <= seq:
            continue
        if beat["spine_event_id"]:
            break
        cards.append(beat["card"])
    return cards


def is_finished(context: PlayContext) -> bool:
    return context.story.get("status") == "completed"


def other_characters(context: PlayContext) -> List[str]:
    viewpoint = context.world.get("viewpoint")
    return [name for name in context.world["characters"] if name != viewpoint]


def available_choices(context: PlayContext) -> List[Dict[str, Any]]:
    """The choices the reader may pick now, picked for variety. Each carries 'lasting' and 'replan'."""
    beat = context.current
    if is_finished(context) or not beat["card"].get("choices"):
        return []
    remaining_spine = context.world["spine"][last_spine_index(context, beat["seq"]) + 1:]
    return offer_choices(context.state, beat["card"], planned_cards_after(context, beat["seq"]), remaining_spine,
                         context.facts, WANTED_CHOICES, other_characters(context))


def present_characters(context: PlayContext) -> List[str]:
    """Living characters where the scene is: the viewpoint's place, or the current scene's cast in an ensemble."""
    chars, viewpoint = context.state["chars"], context.world.get("viewpoint")
    if viewpoint in chars:
        place = chars[viewpoint]["at"]
        return [name for name, character in chars.items() if character["alive"] and character["at"] == place]
    cast, _ = scene_cast(context.current["card"], context.state)
    return [name for name in cast if chars[name]["alive"]]


def play_status(context: PlayContext) -> Dict[str, Any]:
    """What the app shows under the current scene."""
    card, finished = context.current["card"], is_finished(context)
    preparing = not finished and not card.get("choices")
    return {
        "beat_seq": context.current["seq"],
        "question": card.get("question"),
        "choices": [{"id": choice["id"], "label": choice["label"], "lasting": choice["lasting"]}
                    for choice in available_choices(context)],
        "preparing": preparing,
        "finished": finished,
        "present_characters": present_characters(context),
        "callbacks": card.get("callbacks") or [],
    }


# ---------- a turn ----------


@dataclass
class Turn:
    context: PlayContext
    choice: Dict[str, Any]
    next_seq: int
    next_card: Dict[str, Any]
    next_beat_id: Optional[str]  # None when the next beat is a major event reached for the first time
    spine_event: Optional[Dict[str, Any]]
    state_before: State
    state_after_choice: State
    brief: str
    callbacks: List[str] = field(default_factory=list)


def find_choice(context: PlayContext, choice_id: str) -> Dict[str, Any]:
    for choice in available_choices(context):
        if choice["id"] == choice_id:
            return choice
    raise PlayError(409, "지금 고를 수 없는 선택지입니다.")


def apply_choice(state: State, choice: Dict[str, Any]) -> State:
    for event in choice.get("events") or []:
        state = apply_event(state, event, "choice")
    return state


def next_beat(context: PlayContext) -> tuple:
    """(seq, card, beat id or None, the major event or None) of the beat after the current one."""
    current = context.current
    following = [beat for beat in context.beats if beat["seq"] == current["seq"] + 1]
    if following:
        beat = following[0]
        event = context.world["spine"][spine_index(context, beat["spine_event_id"])] if beat["spine_event_id"] else None
        return beat["seq"], beat["card"], beat["id"], event
    index = last_spine_index(context, current["seq"]) + 1
    if index >= len(context.world["spine"]):
        raise PlayError(409, "이야기가 이미 끝났습니다.")
    event = context.world["spine"][index]
    return current["seq"] + 1, spine_event_card(event), None, event


async def replan_rest_of_segment(client: Any, context: PlayContext, state: State, planner: Planner) -> None:
    """A choice broke the rest of this segment: plan it again from the state after the choice."""
    current = context.current
    target = last_spine_index(context, current["seq"]) + 1
    if target >= len(context.world["spine"]):
        return
    cards, _, problems = await plan_segment(context.world, context.plan["seed"], state, target,
                                            planner.fast_model, planner.complete_json)
    if problems:
        logger.warning("Replanned segment of %s still has problems: %s", context.story["id"], problem_lines(problems))
    for beat in context.beats:
        if beat["seq"] > current["seq"] and not beat["spine_event_id"]:
            client.table("story_beats").delete().eq("id", beat["id"]).execute()
    rows = [{"story_id": context.story["id"], "seq": current["seq"] + offset, "spine_event_id": None,
             "card": card, "status": "planned"} for offset, card in enumerate(cards, 1)]
    if rows:
        client.table("story_beats").insert(rows).execute()
    beats = client.table("story_beats").select("*").eq("story_id", context.story["id"]).execute().data or []
    context.beats = sorted(beats, key=lambda beat: beat["seq"])


async def prepare_turn(client: Any, story_id: str, choice_id: str, planner: Planner) -> Turn:
    """Everything before the prose: check the choice, apply it, find the next beat and build its brief."""
    context = load_context(client, story_id)
    if is_finished(context):
        raise PlayError(409, "이야기가 이미 끝났습니다.")
    choice = find_choice(context, choice_id)
    state_before = copy.deepcopy(context.state)
    try:
        state = apply_choice(state_before, choice)
    except EventRejected as rejection:
        raise PlayError(409, f"선택을 적용할 수 없습니다: {rejection}")
    if choice.get("replan"):
        await replan_rest_of_segment(client, context, state, planner)
    seq, card, beat_id, event = next_beat(context)
    return Turn(context, choice, seq, card, beat_id, event, state_before, state,
                build_brief(card, state, context.facts), brief_callbacks(card, state, context.facts))


def previous_tail(client: Any, story_id: str) -> str:
    response = (client.table("scenes").select("content, sequence").eq("story_id", story_id).eq("role", "ai")
                .order("sequence", desc=True).limit(1).execute())
    content = response.data[0]["content"] if response.data else ""
    return content[-PREVIOUS_TAIL_CHARS:]


def stream_turn(client: Any, turn: Turn, planner: Planner) -> AsyncIterator[str]:
    """Write the next scene, piece by piece."""
    context = turn.context
    cast, _ = scene_cast(turn.next_card, turn.state_after_choice)
    system, user = scene_prompt(context.world, context.plan["seed"], turn.brief, cast, turn.next_card.get("intensity"),
                                previous_tail(client, context.story["id"]))
    return planner.stream(system, user, context.story.get("llm_model") or planner.fast_model)


def state_after_beat(turn: Turn) -> State:
    """Apply the beat's own events. A major event fills its unmet needs first, as the spine assumed."""
    facts = turn.context.facts
    if turn.spine_event:
        _, state = walk_spine(turn.state_after_choice, [turn.spine_event], facts)
        return state
    results, state = walk_cards(turn.state_after_choice, [turn.next_card], facts)
    if results[0].errors:
        logger.warning("Beat %s of %s did not fully hold: %s", turn.next_seq, turn.context.story["id"], results[0].errors)
    return state


def turn_events(turn: Turn) -> List[Dict[str, Any]]:
    """What the turn applied, in order, tagged with where each event came from."""
    beat_origin = "spine" if turn.spine_event else "scene"
    return ([{**event, "origin": "choice"} for event in turn.choice.get("events") or []] +
            [{**event, "origin": beat_origin} for event in turn.next_card.get("fixed") or []])


def save_beat(client: Any, turn: Turn) -> str:
    """Mark the beat written with what undo needs. Creates it when a major event is reached for the first time."""
    card = {**turn.next_card, "callbacks": turn.callbacks, "state_before": turn.state_before,
            "previous_seq": turn.context.current["seq"], "chosen": turn.choice["id"]}
    if turn.next_beat_id:
        client.table("story_beats").update({"card": card, "status": "written"}).eq("id", turn.next_beat_id).execute()
        return turn.next_beat_id
    created = client.table("story_beats").insert({
        "story_id": turn.context.story["id"], "seq": turn.next_seq, "spine_event_id": turn.spine_event["id"],
        "card": card, "status": "written"}).execute()
    return created.data[0]["id"]


def claim_turn(client: Any, turn: Turn, state: State) -> bool:
    """Compare-and-set on current_beat_seq, so two turns sent at once cannot both be saved."""
    is_ending = bool(turn.spine_event) and turn.spine_event["id"] == turn.context.world["spine"][-1]["id"]
    result = (client.table("stories")
              .update({"current_beat_seq": turn.next_seq, "world_state": state,
                       **({"status": "completed"} if is_ending else {})})
              .eq("id", turn.context.story["id"]).eq("current_beat_seq", turn.context.current["seq"]).execute())
    return bool(result.data)


def finish_turn(client: Any, turn: Turn, prose: str, client_request_id: Optional[str]) -> Dict[str, Any]:
    """Save the turn: claim it, then the beat and both scenes. Returns the saved scenes."""
    story_id = turn.context.story["id"]
    if not claim_turn(client, turn, state_after_beat(turn)):
        raise PlayError(409, "다른 기기에서 이미 이야기를 진행했습니다.")
    try:
        beat_id = save_beat(client, turn)
        scenes = persist_chat_turn(client, story_id, user_message=turn.choice["label"], ai_message=prose,
                                   client_request_id=client_request_id, ai_beat_id=beat_id, ai_events=turn_events(turn))
    except Exception:
        client.table("stories").update({"current_beat_seq": turn.context.current["seq"], "world_state": turn.state_before,
                                        "status": turn.context.story["status"]}).eq("id", story_id).execute()
        raise
    client.table("story_beats").update({"scene_id": scenes["ai_scene"]["id"]}).eq("id", beat_id).execute()
    client.table("stories").update({"current_scene_id": scenes["ai_scene"]["id"],
                                    "total_scenes": scenes["ai_scene"].get("sequence")}).eq("id", story_id).execute()
    return scenes


def needs_next_segment(turn: Turn) -> bool:
    """A major event other than the ending was just written: its choices and the next segment are planned next."""
    return bool(turn.spine_event) and turn.spine_event["id"] != turn.context.world["spine"][-1]["id"]


# ---------- planning the next segment in the background ----------


def claim_planning(client: Any, story_id: str, owner: str) -> Optional[Dict[str, Any]]:
    """Take the story's lease for segment planning (the story must be ready and nobody holding it)."""
    plan = fetch_plan(client, story_id)
    lease_until = parse_timestamp(plan.get("lease_until")) if plan else None
    if not plan or plan.get("status") != "ready" or (lease_until and lease_until > now_utc()):
        return None
    query = client.table("story_plans").update(
        {"lease_owner": owner, "lease_until": (now_utc() + timedelta(seconds=600)).isoformat()}
    ).eq("story_id", story_id)
    previous_owner = plan.get("lease_owner")
    query = query.eq("lease_owner", previous_owner) if previous_owner else query.is_("lease_owner", "null")
    return {**plan, "lease_owner": owner} if query.execute().data else None


def awaiting_segment(context: PlayContext) -> bool:
    current = context.current
    return bool(current["spine_event_id"]) and not current["card"].get("choices") and not is_finished(context)


async def plan_after_major_event(job: Job, context: PlayContext) -> None:
    """Plan the segment after the current major event, and the choices shown right after its scene."""
    current = context.current
    target = spine_index(context, current["spine_event_id"]) + 1
    feedback, problems = None, []
    for _ in range(MAX_SEGMENT_TRIES):
        job.renew()
        cards, after_event, problems = await plan_segment(context.world, context.plan["seed"], context.state, target,
                                                          job.planner.fast_model, job.planner.complete_json, feedback)
        if not problems:
            break
        feedback = "; ".join(problem_lines(problems))
        job.log_retry(f"segment:{target}", problem_lines(problems))
    if problems:
        raise RuntimeError(f"segment {target}: {feedback}")
    card = {**current["card"], "choices": after_event["choices"], "question": after_event.get("question") or ""}
    job.client.table("story_beats").update({"card": card}).eq("id", current["id"]).execute()
    rows = [{"story_id": job.story_id, "seq": current["seq"] + offset, "spine_event_id": None, "card": planned,
             "status": "planned"} for offset, planned in enumerate(cards, 1)]
    job.client.table("story_beats").insert(rows).execute()


async def plan_next_segment(story_id: str, planner: Optional[Planner] = None, client: Any = None) -> None:
    """Background task. Safe to call repeatedly: one run plans; later calls find nothing to do."""
    story_id = str(story_id)
    if story_id in _planning_story_ids:
        return
    _planning_story_ids.add(story_id)
    job = None
    try:
        if client is None:
            from app.services.supabase_client import get_supabase_client

            client = get_supabase_client()
        context = load_context(client, story_id)
        if not awaiting_segment(context):
            return
        plan = claim_planning(client, story_id, uuid.uuid4().hex)
        if not plan:
            return
        job = Job(client, story_id, plan["lease_owner"], planner or default_planner(), context.story,
                  list(plan.get("retry_log") or []))
        await plan_after_major_event(job, context)
        job.save({"lease_owner": None, "lease_until": None})
    except (LeaseLost, PlayError) as stop:
        logger.warning("Segment planning for %s stopped: %s", story_id, stop)
    except Exception as error:
        logger.exception("Segment planning for %s failed", story_id)
        if job is not None:
            record_planning_failure(job, error)
    finally:
        _planning_story_ids.discard(story_id)


def record_planning_failure(job: Job, error: Exception) -> None:
    """Log the failure and keep the lease a little longer, so a polling app does not start a new plan at once."""
    try:
        job.log_retry("segment", error=f"{type(error).__name__}: {error}")
        job.save({"lease_until": (now_utc() + timedelta(seconds=PLANNING_BACKOFF_SECONDS)).isoformat()})
    except Exception as record_error:
        logger.warning("Could not record a failed segment plan for %s: %s", job.story_id, record_error)


def planning_is_stalled(client: Any, context: PlayContext) -> bool:
    """The current major event still has no choices and nobody is planning them."""
    if not awaiting_segment(context):
        return False
    lease_until = parse_timestamp(fetch_plan(client, context.story["id"]).get("lease_until"))
    return lease_until is None or lease_until < now_utc()


# ---------- undo ----------


def undo_last_turn(client: Any, story_id: str) -> PlayContext:
    """Undo the latest turn: restore the state before it and remove its scenes."""
    context = load_context(client, story_id)
    beat = context.current
    if beat["seq"] <= 1 or "state_before" not in beat["card"]:
        raise PlayError(409, "되돌릴 장면이 없습니다.")
    previous_seq = beat["card"]["previous_seq"]
    previous_scene = next((b.get("scene_id") for b in context.beats if b["seq"] == previous_seq), None)
    result = (client.table("stories")
              .update({"current_beat_seq": previous_seq, "world_state": beat["card"]["state_before"], "status": "active",
                       "current_scene_id": previous_scene})
              .eq("id", story_id).eq("current_beat_seq", beat["seq"]).execute())
    if not result.data:
        raise PlayError(409, "다른 기기에서 이미 이야기를 진행했습니다.")
    _delete_turn_scenes(client, story_id, beat.get("scene_id"))
    _reset_beat(client, context, beat)
    return load_context(client, story_id)


def _delete_turn_scenes(client: Any, story_id: str, ai_scene_id: Optional[str]) -> None:
    scenes = client.table("scenes").select("id, sequence, role").eq("story_id", story_id).execute().data or []
    ai_scene = next((scene for scene in scenes if scene["id"] == ai_scene_id), None)
    if not ai_scene:
        return
    for scene in scenes:
        if scene["sequence"] in (ai_scene["sequence"], ai_scene["sequence"] - 1) and (
                scene["id"] == ai_scene_id or scene.get("role") == "user"):
            client.table("scenes").delete().eq("id", scene["id"]).execute()


def _reset_beat(client: Any, context: PlayContext, beat: Dict[str, Any]) -> None:
    """A planned scene goes back to planned. A major event reached in that turn is removed with what was planned after it."""
    if beat["spine_event_id"]:
        for later in context.beats:
            if later["seq"] >= beat["seq"]:
                client.table("story_beats").delete().eq("id", later["id"]).execute()
        return
    runtime_keys = ("callbacks", "state_before", "previous_seq", "chosen")
    card = {key: value for key, value in beat["card"].items() if key not in runtime_keys}
    client.table("story_beats").update({"card": card, "status": "planned", "scene_id": None}).eq("id", beat["id"]).execute()

