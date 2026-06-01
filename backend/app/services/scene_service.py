import logging
from typing import Any, Dict, Optional
from uuid import UUID

logger = logging.getLogger(__name__)

OPTIONAL_SCENE_COLUMNS = {"role", "image_url", "bgm_url", "client_request_id"}
SCENE_ROLES = {"user", "ai", "system"}
SCENE_TYPES = {"narrative", "dialogue", "choice", "ending"}


def _as_story_id(story_id: UUID | str) -> str:
    return str(story_id)


def _is_missing_optional_column_error(error: Exception) -> bool:
    message = str(error).lower()
    return "column" in message and any(column in message for column in OPTIONAL_SCENE_COLUMNS)


def _normalise_role(role: Optional[str]) -> str:
    if role in SCENE_ROLES:
        return role
    return "ai"


def _normalise_scene_type(scene_type: Optional[str]) -> str:
    if scene_type in SCENE_TYPES:
        return scene_type
    return "narrative"


def _normalise_client_request_id(client_request_id: Optional[str]) -> Optional[str]:
    if not client_request_id:
        return None
    value = client_request_id.strip()
    if not value:
        return None
    return value[:120]


def find_chat_turn_by_client_request_id(
    client: Any,
    story_id: UUID | str,
    client_request_id: Optional[str],
) -> Optional[Dict[str, Any]]:
    """Return an already persisted chat turn for a client request id."""
    request_id = _normalise_client_request_id(client_request_id)
    if not request_id:
        return None

    try:
        response = (
            client.table("scenes")
            .select("*")
            .eq("story_id", _as_story_id(story_id))
            .eq("client_request_id", request_id)
            .order("sequence")
            .execute()
        )
    except Exception as error:
        if _is_missing_optional_column_error(error):
            logger.warning("Scenes table is missing client_request_id. Idempotency is disabled.")
            return None
        raise

    user_scene = None
    ai_scene = None
    for scene in response.data or []:
        if scene.get("role") == "user" and user_scene is None:
            user_scene = scene
        if scene.get("role") == "ai" and ai_scene is None:
            ai_scene = scene

    if user_scene and ai_scene:
        return {
            "user_scene": user_scene,
            "ai_scene": ai_scene,
            "deduplicated": True,
        }
    return None


def get_next_scene_sequence(client: Any, story_id: UUID | str) -> int:
    """Return the next sequence number for a story."""
    response = (
        client.table("scenes")
        .select("sequence")
        .eq("story_id", _as_story_id(story_id))
        .order("sequence", desc=True)
        .limit(1)
        .execute()
    )
    if not response.data:
        return 1

    latest_sequence = response.data[0].get("sequence") or 0
    return int(latest_sequence) + 1


def insert_scene_record(
    client: Any,
    story_id: UUID | str,
    *,
    content: str,
    sequence: Optional[int] = None,
    scene_type: str = "narrative",
    role: str = "ai",
    chapter_id: Optional[UUID | str] = None,
    emotion_score: Optional[float] = None,
    importance_score: Optional[float] = None,
    has_generated_image: bool = False,
    has_generated_bgm: bool = False,
    image_url: Optional[str] = None,
    bgm_url: Optional[str] = None,
    client_request_id: Optional[str] = None,
) -> Dict[str, Any]:
    """Insert a scene row and tolerate older DBs missing new optional columns."""
    if sequence is None:
        sequence = get_next_scene_sequence(client, story_id)

    row: Dict[str, Any] = {
        "story_id": _as_story_id(story_id),
        "content": content,
        "sequence": sequence,
        "scene_type": _normalise_scene_type(scene_type),
        "role": _normalise_role(role),
        "emotion_score": emotion_score,
        "importance_score": importance_score,
        "has_generated_image": has_generated_image,
        "has_generated_bgm": has_generated_bgm,
    }
    if chapter_id is not None:
        row["chapter_id"] = str(chapter_id)
    if image_url is not None:
        row["image_url"] = image_url
    if bgm_url is not None:
        row["bgm_url"] = bgm_url
    normalised_request_id = _normalise_client_request_id(client_request_id)
    if normalised_request_id is not None:
        row["client_request_id"] = normalised_request_id

    try:
        response = client.table("scenes").insert(row).execute()
    except Exception as error:
        if not _is_missing_optional_column_error(error):
            raise

        logger.warning("Scenes table is missing optional service columns. Retrying insert without them.")
        fallback_row = {
            key: value for key, value in row.items() if key not in OPTIONAL_SCENE_COLUMNS
        }
        response = client.table("scenes").insert(fallback_row).execute()

    if not response.data:
        raise ValueError("Failed to insert scene")

    return response.data[0]


def update_story_scene_pointer(client: Any, story_id: UUID | str, scene_id: str, total_scenes: int) -> None:
    """Best-effort update for story progress metadata."""
    try:
        client.table("stories").update(
            {"current_scene_id": scene_id, "total_scenes": total_scenes}
        ).eq("id", _as_story_id(story_id)).execute()
    except Exception as error:
        logger.warning("Failed to update story scene pointer: %s", error)


def persist_chat_turn(
    client: Any,
    story_id: UUID | str,
    *,
    user_message: str,
    ai_message: str,
    client_request_id: Optional[str] = None,
) -> Dict[str, Any]:
    """Persist a user turn and the generated AI continuation as ordered scenes."""
    existing_turn = find_chat_turn_by_client_request_id(
        client,
        story_id,
        client_request_id,
    )
    if existing_turn:
        return existing_turn

    start_sequence = get_next_scene_sequence(client, story_id)
    try:
        user_scene = insert_scene_record(
            client,
            story_id,
            content=user_message,
            sequence=start_sequence,
            scene_type="dialogue",
            role="user",
            has_generated_image=False,
            has_generated_bgm=False,
            client_request_id=client_request_id,
        )
        ai_scene = insert_scene_record(
            client,
            story_id,
            content=ai_message,
            sequence=start_sequence + 1,
            scene_type="narrative",
            role="ai",
            has_generated_image=False,
            has_generated_bgm=False,
            client_request_id=client_request_id,
        )
    except Exception:
        existing_turn = find_chat_turn_by_client_request_id(
            client,
            story_id,
            client_request_id,
        )
        if existing_turn:
            return existing_turn
        raise

    update_story_scene_pointer(
        client,
        story_id,
        scene_id=ai_scene["id"],
        total_scenes=start_sequence + 1,
    )
    return {"user_scene": user_scene, "ai_scene": ai_scene, "deduplicated": False}
