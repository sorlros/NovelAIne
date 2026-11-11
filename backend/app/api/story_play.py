import asyncio
import logging
import os
import time
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Header, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field, model_validator
from starlette.background import BackgroundTask

from app.api.media import media_pending, queue_scene_media, run_media_jobs
from app.schemas.models import ApiResponse
from app.services.auth_context import ensure_story_access
from app.services.external_errors import GENERIC_MESSAGE, ExternalServiceError
from app.services.scene_service import find_chat_turn_by_client_request_id
from app.services.story_generation import default_planner
from app.services.story_play import (
    EchoGuard,
    PlayError,
    claim_turn_slot,
    finish_turn,
    load_context,
    needs_next_segment,
    plan_next_segment,
    planning_is_stalled,
    play_status,
    prepare_input_turn,
    prepare_turn,
    record_turn,
    release_turn_slot,
    stream_turn,
    undo_last_turn,
    use_direct_input,
    wants_media,
)
from app.services.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/stories/{story_id}/play", tags=["play"])

MAX_INPUT_LENGTH = 300
DEFAULT_DAILY_INPUT_LIMIT = 50  # written actions per user per day; DIRECT_INPUT_DAILY_LIMIT overrides
INPUT_LIMIT_MESSAGE = "오늘 쓸 수 있는 직접 입력 {limit}회를 모두 썼습니다. 선택지로 이어 가거나 내일 다시 써 주세요."
TURN_BUSY_MESSAGE = "이야기를 이어 쓰고 있습니다. 잠시 후 다시 시도해 주세요."


class PlayRequest(BaseModel):
    """One of choice_id (an offered choice) or text (the reader's own action)."""

    choice_id: Optional[str] = Field(default=None, min_length=1, max_length=40)
    text: Optional[str] = Field(default=None, max_length=MAX_INPUT_LENGTH)
    client_request_id: Optional[str] = Field(default=None, max_length=120)

    @model_validator(mode="after")
    def one_of_choice_or_text(self):
        self.text = (self.text or "").strip() or None
        if (self.choice_id is None) == (self.text is None):
            raise ValueError("choice_id 와 text 가운데 하나만 보낸다")
        return self


def get_planner():
    """The model calls used for a turn. Replaced in tests."""
    return default_planner()


def _http_error(error: PlayError) -> HTTPException:
    return HTTPException(status_code=error.status_code, detail=error.message)


@router.get("", response_model=ApiResponse)
async def get_play(
    story_id: UUID,
    background_tasks: BackgroundTasks,
    authorization: Optional[str] = Header(default=None),
):
    """Where the reader is: the question, the choices (each with 'lasting'), whether choices are still being
    prepared, whether the story is finished, who is present and which earlier choices the scene called back."""
    try:
        client = get_supabase_client()
        ensure_story_access(client, story_id, authorization)
        context = load_context(client, str(story_id))
        if planning_is_stalled(client, context):
            background_tasks.add_task(plan_next_segment, str(story_id))
        return ApiResponse.ok(data={**play_status(context), "media_pending": media_pending(client, story_id)})
    except PlayError as error:
        raise _http_error(error)
    except HTTPException:
        raise
    except Exception as error:
        logger.error("Failed to read play state of %s: %s", story_id, error)
        raise HTTPException(status_code=500, detail="Failed to read play state")


def _replay_existing(content: str):
    async def replay():
        if content:
            yield content
    return StreamingResponse(replay(), media_type="text/plain")


def daily_input_limit() -> int:
    return int(os.getenv("DIRECT_INPUT_DAILY_LIMIT", str(DEFAULT_DAILY_INPUT_LIMIT)))


async def _prepare(client, story_id: str, request: PlayRequest, user_id: str, planner):
    """Everything before the scene, as HTTP errors. A written action is counted before its model call,
    so a request refused later (rare: the app hides the input then) still uses one."""
    try:
        if request.text is not None:
            limit = daily_input_limit()
            if not use_direct_input(client, user_id, limit):
                raise HTTPException(status_code=429, detail=INPUT_LIMIT_MESSAGE.format(limit=limit))
            return await prepare_input_turn(client, story_id, request.text, planner)
        return await prepare_turn(client, story_id, request.choice_id, planner)
    except PlayError as error:
        raise _http_error(error)
    except ExternalServiceError as error:  # reading the reader's input, or replanning the segment
        raise HTTPException(status_code=503, detail=error.user_message)


def _elapsed_ms(since: float) -> int:
    return int((time.monotonic() - since) * 1000)


async def _write_scene(client, story_id: str, turn, planner, request_id, owner: str, user_id, prepare_ms: int,
                       saved: dict):
    """Stream the scene and save the turn, then record it and free the story's turn slot. A turning point's
    media is queued with the turn and its job ids go into `saved`. The slot is freed when the stream ends or is
    closed; a response never read expires after TURN_SLOT_SECONDS."""
    started, first_chunk_ms, prose = time.monotonic(), None, ""
    outcome, error, scene_id = "failed", "stream closed", None
    guard = EchoGuard(turn.next_card.get("question"))
    try:
        async for chunk in stream_turn(client, turn, planner):
            ready = guard.feed(chunk) if chunk else ""
            if ready:
                first_chunk_ms = first_chunk_ms if first_chunk_ms is not None else _elapsed_ms(started)
                yield ready
        prose = guard.prose
        if not prose.strip():
            raise PlayError(502, GENERIC_MESSAGE)
        rest = guard.finish()
        if rest:
            first_chunk_ms = first_chunk_ms if first_chunk_ms is not None else _elapsed_ms(started)
            yield rest
        scene_id = finish_turn(client, turn, prose, request_id)["ai_scene"]["id"]
        if wants_media(turn):
            saved["media_jobs"] = queue_scene_media(client, story_id, scene_id, user_id)
        outcome, error = "saved", None
    except PlayError as play_error:
        outcome, error = ("conflict" if play_error.status_code == 409 else "failed"), play_error.message
        yield f"\n[STREAM_ERROR:{play_error.message}]"
    except Exception as failure:
        logger.error("Turn of %s failed before it was saved: %s", story_id, failure)
        error = f"{type(failure).__name__}: {failure}"
        message = failure.user_message if isinstance(failure, ExternalServiceError) else GENERIC_MESSAGE
        yield f"\n[STREAM_ERROR:{message}]"
    finally:
        timings = {"prepare_ms": prepare_ms, "first_chunk_ms": first_chunk_ms, "stream_ms": _elapsed_ms(started)}
        record_turn(client, turn, user_id, outcome, timings, prose, error, scene_id)
        release_turn_slot(client, story_id, owner)


@router.post("")
async def post_play(
    story_id: UUID,
    request: PlayRequest,
    authorization: Optional[str] = Header(default=None),
):
    """Pick a choice, or write an action, and stream the next scene as plain text, like /api/chat/stream.

    Written actions are interpreted and checked like choices. One that cannot
    happen is not refused: the scene shows the attempt failing.

    The turn is saved when the scene is complete. A failure while streaming ends
    the stream with [STREAM_ERROR:message] and saves nothing.
    """
    client = get_supabase_client()
    user_id = ensure_story_access(client, story_id, authorization)
    existing = find_chat_turn_by_client_request_id(client, story_id, request.client_request_id)
    if existing:
        return _replay_existing(existing["ai_scene"].get("content", ""))
    owner = claim_turn_slot(client, str(story_id))
    if not owner:
        raise HTTPException(status_code=409, detail=TURN_BUSY_MESSAGE)
    planner = get_planner()
    started = time.monotonic()
    try:
        turn = await _prepare(client, str(story_id), request, user_id, planner)
    except BaseException:
        release_turn_slot(client, str(story_id), owner)
        raise
    saved: dict = {}
    scene = _write_scene(client, str(story_id), turn, planner, request.client_request_id, owner, user_id,
                         _elapsed_ms(started), saved)
    needed = needs_next_segment(turn) or wants_media(turn)
    background = BackgroundTask(after_turn, str(story_id), turn, saved) if needed else None
    return StreamingResponse(scene, media_type="text/plain", background=background)


async def after_turn(story_id: str, turn, saved: dict) -> None:
    """Runs once the scene has been sent. After a major event's scene, plan its choices and the next segment
    while the reader reads (if the turn was not saved, there is nothing to plan), and make the media queued
    with the turn."""
    work = [run_media_jobs(saved.get("media_jobs") or [])]
    if needs_next_segment(turn):
        work.append(plan_next_segment(story_id))
    await asyncio.gather(*work)


@router.post("/undo", response_model=ApiResponse)
async def undo_play(
    story_id: UUID,
    authorization: Optional[str] = Header(default=None),
):
    """Undo the latest turn. The first scene cannot be undone."""
    try:
        client = get_supabase_client()
        ensure_story_access(client, story_id, authorization)
        return ApiResponse.ok(data=play_status(undo_last_turn(client, str(story_id))))
    except PlayError as error:
        raise _http_error(error)
    except HTTPException:
        raise
    except Exception as error:
        logger.error("Failed to undo the last turn of %s: %s", story_id, error)
        raise HTTPException(status_code=500, detail="Failed to undo the last turn")
