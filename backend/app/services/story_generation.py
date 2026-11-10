"""Background generation of skeleton-mode stories.

A create request only inserts rows and returns. The work runs on the server,
independent of the request, so the user may leave the screen or close the app:

    world -> spine (ending and major events) -> segment (first beat cards) -> opening (first scene)

The first segment and the opening scene both need only the spine, so they run
at the same time; the segment is saved first, then the scene.

Each step saves its result and story_plans.step before the next one starts, so
a run that dies (restart, deploy, sleep) resumes from the next step instead of
starting over. A run holds a lease (lease_owner, lease_until). Another run may
take over only after the lease has expired, and taking over is a compare-and-set
on lease_owner, so two runs never work on the same story at once.
"""

import asyncio
import contextlib
import json
import logging
import os
import re
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Sequence, Set, Tuple

from app.llm_models import PRIMARY_FAST_LLM_MODEL, PRIMARY_PRO_LLM_MODEL, normalize_llm_model
from app.services.external_errors import ExternalServiceError
from app.services.scene_service import insert_scene_record
from app.services.story_planner import (
    CompleteJson,
    CompleteStream,
    CompleteText,
    PlanFormatError,
    plan_segment,
    plan_spine,
    plan_world,
    repair_spine,
    write_scene,
)
from app.services.story_skeleton import WHOLE_STORY, build_brief, check_craft, check_spine, scene_cast, walk_spine
from app.services.story_state import build_initial_state

logger = logging.getLogger(__name__)

STEPS = ("none", "world", "spine", "segment", "opening")
ACTIVE_STATUSES = ("queued", "running")
LEASE_SECONDS = 600  # longer than the worst single LLM call (timeout, retry and fallback model)
MAX_ATTEMPTS = 3
MAX_WORLD_TRIES = 2
MAX_SPINE_REPAIRS = 2
MAX_SEGMENT_TRIES = 3
LLM_TIMEOUT_SECONDS = 120.0
RETRY_LOG_LIMIT = 50       # entries kept in story_plans.retry_log
RETRY_LOG_PROBLEMS = 12    # problems kept per entry
FAILURE_MESSAGE = "이야기의 뼈대를 만들지 못했습니다. 다시 시도해 주세요."
ROLE_IN_STORY = {"protagonist": "protagonist", "ally": "supporting", "antagonist": "antagonist", "neutral": "npc"}

# Story ids being generated in this process. The lease guards across processes.
_running_story_ids: Set[str] = set()


def is_skeleton_mode_enabled() -> bool:
    return os.getenv("SKELETON_MODE_ENABLED", "").strip().lower() in {"1", "true", "yes", "on"}


class LeaseLost(Exception):
    """Another run took the job over, or the story was deleted."""


class StepFailed(Exception):
    """A step could not produce a plan that passes the checks."""


# ---------- time ----------


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def parse_timestamp(value: Any) -> Optional[datetime]:
    """Parse a timestamp from the database. Python 3.10 needs the fraction padded to six digits."""
    if not value:
        return None
    if isinstance(value, datetime):
        return value
    text = str(value).replace("Z", "+00:00")
    text = re.sub(r"\.(\d{1,6})\d*", lambda match: "." + match.group(1).ljust(6, "0"), text)
    parsed = datetime.fromisoformat(text)
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def is_stalled(plan: Dict[str, Any], now: Optional[datetime] = None) -> bool:
    """Active and nobody holds a live lease on it."""
    if plan.get("status") not in ACTIVE_STATUSES:
        return False
    lease_until = parse_timestamp(plan.get("lease_until"))
    return lease_until is None or lease_until < (now or now_utc())


# ---------- LLM ----------


@dataclass
class Planner:
    complete_json: CompleteJson
    complete_text: CompleteText
    stream_text: Optional[CompleteStream] = None  # without it, a scene is sent in one piece when it is done
    fast_model: str = PRIMARY_FAST_LLM_MODEL
    pro_model: str = PRIMARY_PRO_LLM_MODEL

    async def stream(self, system: str, user: str, model: str):
        if self.stream_text is None:
            yield await self.complete_text(system, user, model)
            return
        async for chunk in self.stream_text(system, user, model):
            yield chunk


def parse_json_object(text: str) -> Dict[str, Any]:
    """Parse the model's JSON, tolerating code fences and text around the object."""
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end <= start:
        raise PlanFormatError("the response is not a JSON object")
    try:
        parsed = json.loads(text[start:end + 1], strict=False)
    except json.JSONDecodeError as error:
        raise PlanFormatError(f"the response is not valid JSON: {error}") from error
    if not isinstance(parsed, dict):
        raise PlanFormatError("the response is not a JSON object")
    return parsed


def default_planner() -> Planner:
    """Planner backed by OpenRouter through ChatService (model fallback and retry included)."""
    from app.services.chat_service import ChatService

    chat_service = ChatService()

    async def complete(system: str, user: str, model: str, as_json: bool) -> str:
        payload = {
            "model": model,
            "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
            "temperature": 0.7 if as_json else 0.85,
            "max_tokens": 8000 if as_json else 4000,
            **({"response_format": {"type": "json_object"}} if as_json else {}),
        }
        service_name = "OpenRouter story planning" if as_json else "OpenRouter story scene"
        response = await chat_service._post_openrouter(payload, LLM_TIMEOUT_SECONDS, service_name=service_name)
        return chat_service._extract_response_text(response.json()) or ""

    async def complete_json(system: str, user: str, model: str) -> Dict[str, Any]:
        return parse_json_object(await complete(system, user, model, True))

    async def complete_text(system: str, user: str, model: str) -> str:
        return await complete(system, user, model, False)

    async def stream_text(system: str, user: str, model: str):
        payload = {"model": model, "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
                   "temperature": 0.85, "max_tokens": 4000, "stream": True}
        async for chunk in chat_service.stream_payload(payload, "OpenRouter story scene"):
            yield chunk

    return Planner(complete_json, complete_text, stream_text)


# ---------- lease ----------


def fetch_plan(client: Any, story_id: str) -> Optional[Dict[str, Any]]:
    response = client.table("story_plans").select("*").eq("story_id", story_id).limit(1).execute()
    return response.data[0] if response.data else None


def claim_generation(client: Any, story_id: str, owner: str, now: Optional[datetime] = None) -> Optional[Dict[str, Any]]:
    """Take the job if it is active and nobody holds a live lease. Returns the claimed plan or None."""
    now = now or now_utc()
    plan = fetch_plan(client, story_id)
    if not plan or not is_stalled(plan, now):
        return None
    lease_until = (now + timedelta(seconds=LEASE_SECONDS)).isoformat()
    query = client.table("story_plans").update(
        {"status": "running", "lease_owner": owner, "lease_until": lease_until}
    ).eq("story_id", story_id)
    previous_owner = plan.get("lease_owner")
    query = query.eq("lease_owner", previous_owner) if previous_owner else query.is_("lease_owner", "null")
    result = query.execute()
    if not result.data:
        return None  # another run claimed it between our read and our write
    return {**plan, "status": "running", "lease_owner": owner, "lease_until": lease_until}


@dataclass
class Job:
    client: Any
    story_id: str
    owner: str
    planner: Planner
    story: Dict[str, Any] = field(default_factory=dict)
    retry_log: List[Dict[str, Any]] = field(default_factory=list)

    def log_retry(self, step: str, problems: Sequence[str] = (), error: Optional[str] = None) -> None:
        """Record why a step was asked again or failed, so the most common causes can be found and fixed."""
        entry = {"step": step, "at": now_utc().isoformat()}
        if problems:
            entry["problems"] = [str(problem)[:300] for problem in problems[:RETRY_LOG_PROBLEMS]]
        if error:
            entry["error"] = error[:300]
        logger.info("Story generation %s: %s retried: %s", self.story_id, step, entry.get("problems") or error)
        self.retry_log = (self.retry_log + [entry])[-RETRY_LOG_LIMIT:]
        self.save({"retry_log": self.retry_log})

    def save(self, fields: Dict[str, Any]) -> None:
        """Update the plan while still holding the lease. Also renews the lease."""
        lease_until = (now_utc() + timedelta(seconds=LEASE_SECONDS)).isoformat()
        result = (
            self.client.table("story_plans")
            .update({"lease_until": lease_until, **fields})
            .eq("story_id", self.story_id)
            .eq("lease_owner", self.owner)
            .execute()
        )
        if not result.data:
            raise LeaseLost(self.story_id)

    def renew(self) -> None:
        self.save({})

    def update_story(self, fields: Dict[str, Any]) -> None:
        self.client.table("stories").update(fields).eq("id", self.story_id).execute()


# ---------- steps ----------


async def step_world(job: Job, plan: Dict[str, Any]) -> Dict[str, Any]:
    seed, feedback, problems = plan["seed"], None, []
    for _ in range(MAX_WORLD_TRIES):
        job.renew()
        world, problems = await plan_world(seed, job.planner.fast_model, job.planner.complete_json, feedback)
        if not problems:
            break
        feedback = "; ".join(problems)
        job.log_retry("world", problems)
    if problems:
        raise StepFailed(f"world: {feedback}")
    job.save({"world": world, "step": "world"})
    title = seed.get("title") or world["title"]
    job.update_story({"title": title or job.story.get("title"), "description": world["logline"] or None})
    return {**plan, "world": world, "step": "world"}


def spine_problems(world: Dict[str, Any], events: List[Dict[str, Any]]) -> List[Tuple[str, str]]:
    planned = {**world, "spine": events}
    problems = list(check_spine(planned).errors) + check_craft(planned)
    if len(events) < 2:
        problems.append((WHOLE_STORY, "주요 사건이 두 개 이상이어야 한다"))
    return problems


def problem_lines(problems: Sequence[Tuple[str, str]]) -> List[str]:
    return [f"{item_id}: {reason}" for item_id, reason in problems]


async def step_spine(job: Job, plan: Dict[str, Any]) -> Dict[str, Any]:
    seed, model, complete = plan["seed"], job.planner.pro_model, job.planner.complete_json
    job.renew()
    ending, facts, events = await plan_spine(plan["world"], seed, model, complete)
    world = {**plan["world"], "facts": facts}
    problems = spine_problems(world, events)
    for _ in range(MAX_SPINE_REPAIRS):
        if not problems:
            break
        job.log_retry("spine", problem_lines(problems))
        facts, events = await repair_spine(world, seed, events, problems, model, complete)
        world = {**world, "facts": facts}
        problems = spine_problems(world, events)
    if problems:
        raise StepFailed("spine: " + "; ".join(f"{event_id}: {reason}" for event_id, reason in problems))
    spine = {"ending": ending, "events": events}
    job.save({"world": world, "spine": spine, "step": "spine"})
    return {**plan, "world": world, "spine": spine, "step": "spine"}


def planned_world(plan: Dict[str, Any]) -> Dict[str, Any]:
    return {**plan["world"], "spine": plan["spine"]["events"]}


def spine_event_card(event: Dict[str, Any], choices: Sequence[Dict[str, Any]] = (), question: str = "") -> Dict[str, Any]:
    keys = ("id", "title", "meaning", "intensity", "needs", "plants", "pays")
    card = {**{key: event.get(key) for key in keys}, "fixed": event["events"], "choices": list(choices)}
    return {**card, "question": question} if question else card


def save_first_beats(job: Job, first_event: Dict[str, Any], after_event: Dict[str, Any], cards: Sequence[Dict[str, Any]]) -> None:
    """Replace the story's beat cards: the first major event, then the first segment."""
    job.client.table("story_beats").delete().eq("story_id", job.story_id).execute()
    card = spine_event_card(first_event, after_event["choices"], after_event.get("question") or "")
    rows = [{"story_id": job.story_id, "seq": 1, "spine_event_id": first_event["id"], "card": card, "status": "planned"}]
    rows += [{"story_id": job.story_id, "seq": seq, "spine_event_id": None, "card": card, "status": "planned"}
             for seq, card in enumerate(cards, 2)]
    job.client.table("story_beats").insert(rows).execute()


async def step_segment(job: Job, plan: Dict[str, Any]) -> Dict[str, Any]:
    world = planned_world(plan)
    _, state = walk_spine(build_initial_state(world), world["spine"][:1], world["facts"])
    feedback, problems = None, []
    for _ in range(MAX_SEGMENT_TRIES):
        job.renew()
        cards, after_event, problems = await plan_segment(
            world, plan["seed"], state, 1, job.planner.fast_model, job.planner.complete_json, feedback
        )
        if not problems:
            break
        feedback = "; ".join(problem_lines(problems))
        job.log_retry("segment", problem_lines(problems))
    if problems:
        raise StepFailed(f"segment: {feedback}")
    save_first_beats(job, world["spine"][0], after_event, cards)
    job.save({"step": "segment"})
    return {**plan, "step": "segment"}


def fetch_first_beat(client: Any, story_id: str) -> Dict[str, Any]:
    response = client.table("story_beats").select("*").eq("story_id", story_id).eq("seq", 1).limit(1).execute()
    if not response.data:
        raise StepFailed("opening: the first beat card is missing")
    return response.data[0]


def fetch_scene_for_beat(client: Any, story_id: str, beat_id: str) -> Optional[Dict[str, Any]]:
    response = client.table("scenes").select("*").eq("story_id", story_id).eq("beat_id", beat_id).limit(1).execute()
    return response.data[0] if response.data else None


async def draft_opening(job: Job, plan: Dict[str, Any]) -> str:
    """Write the first scene from the first major event. Needs only the spine, so it can run beside the segment."""
    world = planned_world(plan)
    card, state = spine_event_card(world["spine"][0]), build_initial_state(world)
    job.renew()
    return await write_scene(world, plan["seed"], build_brief(card, state, world["facts"]), scene_cast(card, state)[0],
                             card.get("intensity"), job.story.get("llm_model") or job.planner.fast_model,
                             job.planner.complete_text, is_opening=True)


async def step_opening(job: Job, plan: Dict[str, Any], drafted: Optional[str] = None) -> Dict[str, Any]:
    """Save the first scene. A scene already saved is kept; without a draft (a resumed run) it is written now."""
    beat = fetch_first_beat(job.client, job.story_id)
    if not fetch_scene_for_beat(job.client, job.story_id, beat["id"]):
        text = drafted or await draft_opening(job, plan)
        job.renew()
        insert_scene_record(job.client, job.story_id, content=text, sequence=1, scene_type="narrative",
                            role="ai", beat_id=beat["id"], events=beat["card"]["fixed"])
    job.save({"step": "opening"})
    return {**plan, "step": "opening"}


async def step_segment_and_opening(job: Job, plan: Dict[str, Any]) -> Dict[str, Any]:
    """Plan the first segment and write the opening scene at the same time. The segment is saved first."""
    opening = asyncio.ensure_future(draft_opening(job, plan))
    try:
        plan = await step_segment(job, plan)
    except BaseException:
        opening.cancel()
        with contextlib.suppress(BaseException):
            await opening
        raise
    return await step_opening(job, plan, await opening)


# ---------- finishing ----------


def ensure_characters(job: Job, plan: Dict[str, Any]) -> None:
    """Create the story's characters once. Skipped when they already exist (a resumed run)."""
    existing = job.client.table("story_characters").select("character_id").eq("story_id", job.story_id).execute()
    if existing.data:
        return
    seed, user_id = plan["seed"], job.story.get("user_id")
    for name, character in plan["world"]["characters"].items():
        is_protagonist = character["role"] == "protagonist"
        row = {"name": name, "description": character["wants"] or plan["world"]["premise"], "user_id": user_id,
               "personality_traits": seed.get("protagonist_traits") if is_protagonist else None,
               "appearance_description": seed.get("protagonist_appearance_description") if is_protagonist else None}
        created = job.client.table("characters").insert(row).execute()
        if created.data:
            job.client.table("story_characters").insert({
                "story_id": job.story_id, "character_id": created.data[0]["id"],
                "role_in_story": ROLE_IN_STORY.get(character["role"], "npc"),
            }).execute()


def finish_generation(job: Job, plan: Dict[str, Any]) -> None:
    world = planned_world(plan)
    beat = fetch_first_beat(job.client, job.story_id)
    scene = fetch_scene_for_beat(job.client, job.story_id, beat["id"])
    if not scene:
        raise StepFailed("finish: the opening scene is missing")
    _, state = walk_spine(build_initial_state(world), world["spine"][:1], world["facts"])
    ensure_characters(job, plan)
    job.client.table("story_beats").update({"status": "written", "scene_id": scene["id"]}).eq("id", beat["id"]).execute()
    job.update_story({"status": "active", "world_state": state, "current_beat_seq": 1,
                      "total_scenes": 1, "current_scene_id": scene["id"]})
    job.save({"status": "ready", "error": None, "lease_owner": None, "lease_until": None})


STEP_RUNNERS = {"none": step_world, "world": step_spine, "spine": step_segment_and_opening, "segment": step_opening}


async def advance(job: Job, plan: Dict[str, Any]) -> Dict[str, Any]:
    """Run every step after the one recorded in the plan."""
    while plan.get("step") in STEP_RUNNERS:
        plan = await STEP_RUNNERS[plan["step"]](job, plan)
    return plan


# ---------- running ----------


def user_message_for(error: Exception) -> str:
    if isinstance(error, ExternalServiceError):
        return error.user_message
    return FAILURE_MESSAGE


def record_failure(job: Job, attempts: int, error: Exception) -> bool:
    """Record a failed attempt. Returns True when the job has given up."""
    message = user_message_for(error)
    if attempts < MAX_ATTEMPTS:
        job.save({"attempts": attempts, "error": message})
        return False
    job.save({"attempts": attempts, "error": message, "status": "failed", "lease_owner": None, "lease_until": None})
    job.update_story({"status": "failed"})
    return True


def load_story(client: Any, story_id: str) -> Dict[str, Any]:
    response = client.table("stories").select("*").eq("id", story_id).limit(1).execute()
    return response.data[0] if response.data else {}


async def run_claimed(job: Job, plan: Dict[str, Any]) -> None:
    attempts = int(plan.get("attempts") or 0)
    while True:
        try:
            plan = await advance(job, plan)
            finish_generation(job, plan)
            return
        except LeaseLost:
            raise
        except Exception as error:  # every failure counts as an attempt; the job must not stay running
            attempts += 1
            plan = fetch_plan(job.client, job.story_id) or plan  # resume from the last step that was saved
            logger.exception("Story generation %s failed after step '%s' (attempt %s)", job.story_id, plan.get("step"), attempts)
            job.log_retry(f"after:{plan.get('step')}", error=f"{type(error).__name__}: {error}")
            if record_failure(job, attempts, error):
                return


async def run_generation(story_id: str, planner: Optional[Planner] = None, client: Any = None) -> None:
    """Generate a story to the end, or resume it. Safe to call more than once: only one run proceeds."""
    story_id = str(story_id)
    if story_id in _running_story_ids:
        return
    _running_story_ids.add(story_id)
    try:
        if client is None:
            from app.services.supabase_client import get_supabase_client

            client = get_supabase_client()
        owner = uuid.uuid4().hex
        plan = claim_generation(client, story_id, owner)
        if not plan:
            return
        job = Job(client, story_id, owner, planner or default_planner(), load_story(client, story_id),
                  list(plan.get("retry_log") or []))
        await run_claimed(job, plan)
    except LeaseLost:
        logger.warning("Story generation %s stopped: lease lost or story deleted", story_id)
    except Exception:
        logger.exception("Story generation %s crashed", story_id)
    finally:
        _running_story_ids.discard(story_id)


def stalled_story_ids(client: Any, story_ids: Optional[Sequence[str]] = None) -> List[str]:
    """Active generations whose runner is gone. Limited to story_ids when given."""
    query = client.table("story_plans").select("story_id, status, lease_until").in_("status", list(ACTIVE_STATUSES))
    if story_ids is not None:
        if not story_ids:
            return []
        query = query.in_("story_id", [str(story_id) for story_id in story_ids])
    now = now_utc()
    return [str(row["story_id"]) for row in (query.execute().data or []) if is_stalled(row, now)]


async def resume_stalled_generations(client: Any = None) -> None:
    """Resume every stalled generation. Called once when the server starts."""
    try:
        if client is None:
            from app.services.supabase_client import get_supabase_client

            client = get_supabase_client()
        story_ids = stalled_story_ids(client)
    except Exception:
        logger.exception("Failed to look for stalled story generations")
        return
    await asyncio.gather(*(run_generation(story_id, client=client) for story_id in story_ids))


# ---------- creating and inspecting jobs (used by the stories API) ----------

MAX_CONCURRENT_GENERATIONS = 2
PLACEHOLDER_TITLES = {"ko": "새 이야기"}
SEED_FIELDS = ("genre", "tone", "narrative_type", "protagonist_name", "protagonist_traits",
               "protagonist_appearance_description", "opening_scenario", "language", "llm_model", "title")


class GenerationLimitReached(Exception):
    """The user already has the maximum number of stories being generated."""


class RequestIdConflict(Exception):
    """The request id belongs to another user's story."""


def generation_status(plan: Dict[str, Any]) -> Dict[str, Any]:
    """What the app may see. Never the world, the ending or the major events."""
    return {key: plan.get(key) for key in ("status", "step", "error", "attempts")}


def _find_story_by_request_id(client: Any, request_id: str, user_id: str) -> Optional[Dict[str, Any]]:
    plans = client.table("story_plans").select("story_id").eq("request_id", request_id).limit(1).execute()
    if not plans.data:
        return None
    story = load_story(client, str(plans.data[0]["story_id"]))
    if story and str(story.get("user_id")) != str(user_id):
        raise RequestIdConflict(request_id)
    return story or None


def _placeholder_title(language: Optional[str]) -> str:
    return PLACEHOLDER_TITLES.get((language or "ko").split("-")[0].split("_")[0].lower(), "New story")


def _new_story_row(story_create: Any, user_id: str) -> Dict[str, Any]:
    row = {
        "user_id": user_id,
        "title": story_create.title or _placeholder_title(story_create.language),
        "genre": story_create.genre,
        "description": story_create.description,
        "status": "generating",
        "mode": "skeleton",
        "total_scenes": 0,
        "llm_model": normalize_llm_model(story_create.llm_model),
        "narrative_type": story_create.narrative_type or "hero",
        "visibility": story_create.visibility or "private",
    }
    if row["visibility"] == "public":
        row["published_at"] = now_utc().isoformat()
    return row


def create_skeleton_story(client: Any, story_create: Any, user_id: str) -> Tuple[Dict[str, Any], bool]:
    """Insert the story and its queued generation job. Returns (story, created).

    A request id seen before returns the existing story with created False.
    """
    request_id = story_create.request_id
    if request_id:
        existing = _find_story_by_request_id(client, request_id, user_id)
        if existing:
            return existing, False
    generating = client.table("stories").select("id").eq("user_id", user_id).eq("status", "generating").execute()
    if len(generating.data or []) >= MAX_CONCURRENT_GENERATIONS:
        raise GenerationLimitReached(user_id)
    story = client.table("stories").insert(_new_story_row(story_create, user_id)).execute().data[0]
    seed = {key: getattr(story_create, key, None) for key in SEED_FIELDS}
    try:
        client.table("story_plans").insert({
            "story_id": story["id"], "seed": seed, "request_id": request_id, "status": "queued", "step": "none",
        }).execute()
    except Exception:
        # Most likely a concurrent request with the same id won the unique index. Keep its story.
        client.table("stories").delete().eq("id", story["id"]).execute()
        existing = _find_story_by_request_id(client, request_id, user_id) if request_id else None
        if existing:
            return existing, False
        raise
    return story, True


def reset_failed_generation(client: Any, story_id: str) -> bool:
    """Queue a failed generation again from the step where it stopped. Returns False if it was not failed."""
    result = (
        client.table("story_plans")
        .update({"status": "queued", "attempts": 0, "error": None, "lease_owner": None, "lease_until": None})
        .eq("story_id", story_id)
        .eq("status", "failed")
        .execute()
    )
    if not result.data:
        return False
    client.table("stories").update({"status": "generating"}).eq("id", story_id).execute()
    return True
