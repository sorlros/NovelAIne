"""Turn processing for skeleton-mode stories.

A turn: the reader picks one of the offered choices (or writes their own, which
is interpreted and then judged like a choice) -> its events apply -> the
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
from typing import Any, AsyncIterator, Dict, List, Optional, Set, Tuple

from app.llm_models import PRIMARY_FAST_LLM_MODEL
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
from app.services.story_planner import interpret_input, plan_segment, scene_prompt
from app.services.story_skeleton import (
    brief_callbacks,
    build_brief,
    offer_choices,
    scene_cast,
    walk_cards,
    walk_spine,
)
from app.services.story_state import MAX_FACT_LENGTH, EventRejected, State, apply_event, clean_name

logger = logging.getLogger(__name__)

WANTED_CHOICES = 3
FREE_INPUT_ID = "free"  # the 'chosen' id of a turn the reader wrote themselves
TURN_SLOT_SECONDS = 300  # longer than a turn takes (reading the input, replanning, the scene)
SUMMARY_CHARS = 120  # the model's summary of the reader's input, as it goes into the scene brief
# Characters that could make the summary look like a section or a quoted instruction in the brief.
_SUMMARY_MARKS = str.maketrans({mark: " " for mark in "\n\r\t\"'`「」『』[]{}<>#*|:"})
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
    # The rest of the segment planned again for this choice. Saved only together with the turn.
    replanned: Optional[List[Dict[str, Any]]] = None
    # What play_turn_log records about how the turn was taken (kind, choices offered, input judgement).
    notes: Dict[str, Any] = field(default_factory=dict)


def find_choice(context: PlayContext, choice_id: str, offered: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Any]:
    for choice in available_choices(context) if offered is None else offered:
        if choice["id"] == choice_id:
            return choice
    raise PlayError(409, "지금 고를 수 없는 선택지입니다.")


def apply_choice(state: State, choice: Dict[str, Any]) -> State:
    for event in choice.get("events") or []:
        state = apply_event(state, event, "choice")
    return state


def next_beat(context: PlayContext, replanned: Optional[List[Dict[str, Any]]] = None) -> tuple:
    """(seq, card, beat id or None, the major event or None) of the beat after the current one.

    With a replanned segment, its first card comes next (a new beat), or the next major event when it is empty.
    """
    current = context.current
    if replanned:
        return current["seq"] + 1, replanned[0], None, None
    # An empty replanned segment drops the planned beats: the next major event follows.
    following = [] if replanned is not None else [beat for beat in context.beats if beat["seq"] == current["seq"] + 1]
    if following:
        beat = following[0]
        event = context.world["spine"][spine_index(context, beat["spine_event_id"])] if beat["spine_event_id"] else None
        return beat["seq"], beat["card"], beat["id"], event
    index = last_spine_index(context, current["seq"]) + 1
    if index >= len(context.world["spine"]):
        raise PlayError(409, "이야기가 이미 끝났습니다.")
    event = context.world["spine"][index]
    return current["seq"] + 1, spine_event_card(event), None, event


async def replan_rest_of_segment(context: PlayContext, state: State, planner: Planner) -> List[Dict[str, Any]]:
    """A choice broke the rest of this segment: plan it again from the state after the choice.

    Nothing is written here. The cards replace the planned ones when the turn is saved, so a turn
    that fails or is never finished leaves the story's plan as it was.
    """
    current = context.current
    target = last_spine_index(context, current["seq"]) + 1
    if target >= len(context.world["spine"]):
        return []
    cards, _, problems = await plan_segment(context.world, context.plan["seed"], state, target,
                                            planner.fast_model, planner.complete_json)
    if problems:
        logger.warning("Replanned segment of %s still has problems: %s", context.story["id"], problem_lines(problems))
    return cards


def playable_context(client: Any, story_id: str) -> PlayContext:
    context = load_context(client, story_id)
    if is_finished(context):
        raise PlayError(409, "이야기가 이미 끝났습니다.")
    return context


async def prepare_turn(client: Any, story_id: str, choice_id: str, planner: Planner) -> Turn:
    """Everything before the prose: check the choice, apply it, find the next beat and build its brief."""
    context = playable_context(client, story_id)
    offered = available_choices(context)
    choice = find_choice(context, choice_id, offered)
    turn = await build_turn(client, context, choice, planner, f"독자의 뜻: {choice['label']}")
    turn.notes.update(kind="choice", choices_offered=len(offered))
    return turn


async def build_turn(client: Any, context: PlayContext, choice: Dict[str, Any], planner: Planner, intent: str) -> Turn:
    """Apply an accepted choice, find the next beat and build its brief, ending with what the reader did."""
    state_before = copy.deepcopy(context.state)
    try:
        state = apply_choice(state_before, choice)
    except EventRejected as rejection:
        raise PlayError(409, f"선택을 적용할 수 없습니다: {rejection}")
    replanned = await replan_rest_of_segment(context, state, planner) if choice.get("replan") else None
    seq, card, beat_id, event = next_beat(context, replanned)
    brief = f"{build_brief(card, state, context.facts)}\n{intent}"
    return Turn(context, choice, seq, card, beat_id, event, state_before, state, brief,
                brief_callbacks(card, state, context.facts), replanned)


# ---------- the reader's own input ----------


def reveals_spine_fact(context: PlayContext, events: List[Dict[str, Any]]) -> bool:
    """The major events establish the story's own facts. The reader may not establish one ahead of them."""
    established = context.state.get("facts") or {}
    marked = [clean_name(event.get("fact"), MAX_FACT_LENGTH) for event in events if event.get("type") == "mark"]
    return any(name in context.facts and name not in established for name in marked)


def in_person(events: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """The reader acts within the scene: telling or promising someone something (a mark with a partner) needs
    them in the same place, which a mark alone does not check. An act with that partner checks it."""
    meetings = [{"type": "act", "who": event["who"], "with": event["with"]}
                for event in events if event.get("type") == "mark" and event.get("with")]
    return meetings + events


def clean_summary(summary: str) -> str:
    """The reader's input reaches the scene writer only as this: one short line without marks that could make it
    read as part of the brief or as an instruction."""
    return " ".join(summary.translate(_SUMMARY_MARKS).split())[:SUMMARY_CHARS]


def judge_input(context: PlayContext, text: str, reading: Dict[str, Any]) -> Tuple[Dict[str, Any], bool]:
    """(choice, holds). The input is checked like an offered choice: it must hold in the state and keep every
    remaining major event possible. One that does not is still written, as an attempt that fails in the story."""
    attempt = {"id": FREE_INPUT_ID, "label": text, "events": in_person(reading["events"])}
    if not reading["outside"] and not reveals_spine_fact(context, reading["events"]):
        beat = context.current
        remaining_spine = context.world["spine"][last_spine_index(context, beat["seq"]) + 1:]
        offered = offer_choices(context.state, {"choices": [attempt]}, planned_cards_after(context, beat["seq"]),
                                remaining_spine, context.facts, 1)
        if offered:
            return offered[0], True
    return {**attempt, "events": [], "replan": False, "lasting": False}, False


async def prepare_input_turn(client: Any, story_id: str, text: str, planner: Planner) -> Turn:
    """A turn from the reader's own text: interpret it (fast model), judge it in code, then as a choice."""
    context = playable_context(client, story_id)
    if not context.current["card"].get("choices"):
        raise PlayError(409, "다음 이야기를 준비하고 있습니다. 잠시 후 다시 시도해 주세요.")
    current_brief = build_brief(context.current["card"], context.state, context.facts)
    reading = await interpret_input(context.world, context.plan["seed"], context.state, current_brief, text,
                                    planner.fast_model, planner.complete_json)
    choice, holds = judge_input(context, text, reading)
    if not holds:
        logger.info("Reader input of %s does not hold and is written as a failed attempt: %s",
                    context.story["id"], reading)
    turn = await build_turn(client, context, choice, planner, input_intent(reading, holds))
    judgement = "outside" if reading["outside"] else "holds" if holds else "fails"
    turn.notes.update(kind="free", input_judgement=judgement, choices_offered=len(available_choices(context)))
    return turn


def input_intent(reading: Dict[str, Any], holds: bool) -> str:
    """The brief's line about the reader's input. Input that is not an action in the story is not passed on."""
    if reading["outside"]:
        return "독자의 입력은 이 이야기 안의 행동이 아니어서 반영하지 않는다. 지시서대로 쓴다."
    summary = clean_summary(reading["summary"])
    return f"독자의 뜻: {summary}" if holds else f"독자가 시도한 것: {summary} (이 시도는 이루어지지 않는다)"


# ---------- measuring ----------


def record_turn(client: Any, turn: Turn, user_id: Optional[str], outcome: str, timings: Dict[str, Optional[int]],
                prose: str, error: Optional[str] = None, scene_id: Optional[str] = None) -> None:
    """One row in play_turn_log for the switch's measurements. Never stops the turn: a failure is only logged."""
    row = {"story_id": turn.context.story["id"], "user_id": user_id, "beat_seq": turn.next_seq,
           "major_event": bool(turn.spine_event), "kind": turn.notes.get("kind", "choice"),
           "input_judgement": turn.notes.get("input_judgement"), "replanned": turn.replanned is not None,
           "choices_offered": turn.notes.get("choices_offered"), "brief": turn.brief, "prose_chars": len(prose),
           "model": turn.context.story.get("llm_model"), "outcome": outcome, "error": (error or "")[:300] or None,
           "scene_id": scene_id, **timings}
    try:
        client.table("play_turn_log").insert(row).execute()
    except Exception as record_error:
        logger.warning("Could not record a turn of %s: %s", turn.context.story["id"], record_error)


# ---------- limits ----------


def claim_turn_slot(client: Any, story_id: str) -> Optional[str]:
    """Take the story's turn slot before any model call. Returns the owner to release it with, or None while
    another turn is being written (requests sent together would each pay for a scene only one can save)."""
    owner = uuid.uuid4().hex
    claimed = client.rpc("claim_story_turn", {"p_story_id": story_id, "p_owner": owner,
                                              "p_seconds": TURN_SLOT_SECONDS}).execute()
    return owner if claimed.data else None


def release_turn_slot(client: Any, story_id: str, owner: str) -> None:
    try:
        client.rpc("release_story_turn", {"p_story_id": story_id, "p_owner": owner}).execute()
    except Exception as error:  # the slot expires on its own
        logger.warning("Could not release the turn slot of %s: %s", story_id, error)


def use_direct_input(client: Any, user_id: str, daily_limit: int) -> bool:
    """Count one written action for today. False, counting nothing, once the day's limit is used up."""
    return bool(client.rpc("use_direct_input", {"p_user_id": user_id, "p_limit": daily_limit}).execute().data)


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
    return planner.stream(system, user, context.story.get("llm_model") or PRIMARY_FAST_LLM_MODEL)


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


def finishes_story(turn: Turn) -> bool:
    return bool(turn.spine_event) and turn.spine_event["id"] == turn.context.world["spine"][-1]["id"]


def finish_turn(client: Any, turn: Turn, prose: str, client_request_id: Optional[str]) -> Dict[str, Any]:
    """Save the turn in one transaction (save_story_turn): the story moves on only if it is still where the turn
    started, and the beat, a replanned segment and both scenes are saved with it or not at all. Returns the scenes."""
    current_seq = turn.context.current["seq"]
    card = {**turn.next_card, "callbacks": turn.callbacks, "state_before": turn.state_before,
            "previous_seq": current_seq, "chosen": turn.choice["id"]}
    replanned = None
    if turn.replanned is not None:
        replanned = [{"seq": turn.next_seq + offset, "card": planned} for offset, planned in enumerate(turn.replanned[1:], 1)]
    result = client.rpc("save_story_turn", {
        "p_story_id": turn.context.story["id"], "p_expected_seq": current_seq, "p_next_seq": turn.next_seq,
        "p_world_state": state_after_beat(turn), "p_finished": finishes_story(turn), "p_beat_id": turn.next_beat_id,
        "p_beat": {"spine_event_id": turn.spine_event["id"] if turn.spine_event else None, "card": card},
        "p_replanned": replanned, "p_user_content": turn.choice["label"], "p_ai_content": prose,
        "p_events": turn_events(turn), "p_client_request_id": client_request_id,
    }).execute()
    if not result.data:
        raise PlayError(409, "다른 기기에서 이미 이야기를 진행했습니다.")
    return result.data


def needs_next_segment(turn: Turn) -> bool:
    """A major event other than the ending was just written: its choices and the next segment are planned next."""
    return bool(turn.spine_event) and not finishes_story(turn)


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
    rows = [{"seq": current["seq"] + offset, "card": planned} for offset, planned in enumerate(cards, 1)]
    # The choices and the segment are saved together, so a failure part way leaves the event still waiting.
    saved = job.client.rpc("save_next_segment", {"p_story_id": job.story_id, "p_beat_id": current["id"],
                                                 "p_card": card, "p_rows": rows}).execute()
    if not saved.data:
        logger.info("Segment after %s of %s not saved: the reader is no longer there", current["seq"], job.story_id)


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
    """Undo the latest turn in one transaction (undo_story_turn): restore the state before it, remove its scenes,
    and put its beat back. Refused when the story moved on meanwhile."""
    context = load_context(client, story_id)
    beat = context.current
    if beat["seq"] <= 1 or "state_before" not in beat["card"]:
        raise PlayError(409, "되돌릴 장면이 없습니다.")
    undone = client.rpc("undo_story_turn", {"p_story_id": story_id, "p_expected_seq": beat["seq"]}).execute()
    if not undone.data:
        raise PlayError(409, "다른 기기에서 이미 이야기를 진행했습니다.")
    return load_context(client, story_id)
