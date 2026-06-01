import logging
from typing import Any, Optional
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Header, HTTPException
from pydantic import BaseModel, Field

from app.schemas.models import ApiResponse
from app.services.external_errors import GENERIC_MESSAGE, TEMPORARY_MESSAGE, ExternalServiceError
from app.services.audio_service import AudioService
from app.services.auth_context import ensure_story_access
from app.services.image_service import ImageService
from app.services.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/media", tags=["media"])


class MediaJobCreate(BaseModel):
    story_id: UUID
    scene_id: UUID
    media_type: str = Field(..., pattern="^(image|bgm)$")
    prompt: Optional[str] = Field(default=None, max_length=1000)
    scene_type: str = Field(default="event", pattern="^(dialogue|event)$")


def _build_prompt(media_type: str, scene_content: str, requested_prompt: Optional[str]) -> str:
    if requested_prompt and requested_prompt.strip():
        return requested_prompt.strip()
    if media_type == "bgm":
        return (
            "cinematic instrumental background music, subtle loop, emotional, "
            f"{scene_content[:400]}"
        )
    return f"{scene_content[:400]}, anime style, cinematic composition"


def _normalise_job(row: dict, scene: Optional[dict] = None) -> dict:
    return {"job": row, "scene": scene}


def _fetch_scene(client: Any, story_id: UUID | str, scene_id: UUID | str) -> dict:
    response = (
        client.table("scenes")
        .select("*")
        .eq("id", str(scene_id))
        .eq("story_id", str(story_id))
        .single()
        .execute()
    )
    if not response.data:
        raise HTTPException(status_code=404, detail="Scene not found")
    return response.data


def _fetch_protagonist_appearance(client: Any, story_id: str) -> Optional[str]:
    link_response = (
        client.table("story_characters")
        .select("character_id")
        .eq("story_id", story_id)
        .eq("role_in_story", "protagonist")
        .limit(1)
        .execute()
    )
    if not link_response.data:
        return None

    character_id = link_response.data[0]["character_id"]
    character_response = (
        client.table("characters")
        .select("appearance_description")
        .eq("id", character_id)
        .single()
        .execute()
    )
    if not character_response.data:
        return None
    return character_response.data.get("appearance_description")


def _update_job(client: Any, job_id: str, updates: dict) -> None:
    client.table("media_jobs").update(updates).eq("id", job_id).execute()


def _safe_job_error(error: Exception) -> str:
    if isinstance(error, ExternalServiceError):
        return error.user_message[:1000]
    message = str(error) or GENERIC_MESSAGE
    if "generation failed" in message.lower() or "upload" in message.lower():
        return TEMPORARY_MESSAGE
    return message[:1000]


async def _run_media_job(job_id: str) -> None:
    client = get_supabase_client()
    try:
        job_response = (
            client.table("media_jobs")
            .select("*")
            .eq("id", job_id)
            .single()
            .execute()
        )
        if not job_response.data:
            logger.warning("Media job %s was not found", job_id)
            return

        job = job_response.data
        _update_job(client, job_id, {"status": "running", "error": None})
        scene = _fetch_scene(client, job["story_id"], job["scene_id"])
        prompt = _build_prompt(
            job["media_type"],
            scene.get("content") or "",
            job.get("prompt"),
        )

        if job["media_type"] == "bgm":
            result_url = await AudioService().generate_scene_bgm(prompt, job["scene_id"])
            if not result_url:
                raise RuntimeError(TEMPORARY_MESSAGE)
            client.table("scenes").update(
                {"bgm_url": result_url, "has_generated_bgm": True}
            ).eq("id", job["scene_id"]).execute()
            try:
                client.table("generated_bgms").insert(
                    {
                        "scene_id": job["scene_id"],
                        "prompt": prompt,
                        "audio_url": result_url,
                        "storage_path": result_url,
                        "mood": "cinematic",
                    }
                ).execute()
            except Exception as error:
                logger.warning("Failed to insert generated_bgm record: %s", error)
        else:
            appearance = _fetch_protagonist_appearance(client, job["story_id"])
            result_url = await ImageService().generate_anime_image(
                prompt=prompt,
                scene_type=job.get("scene_type") or "event",
                message_id=job["scene_id"],
                character_appearance=appearance,
            )
            if not result_url:
                raise RuntimeError(TEMPORARY_MESSAGE)
            client.table("scenes").update(
                {"image_url": result_url, "has_generated_image": True}
            ).eq("id", job["scene_id"]).execute()
            try:
                client.table("generated_images").insert(
                    {
                        "scene_id": job["scene_id"],
                        "prompt": prompt,
                        "image_url": result_url,
                        "storage_path": result_url,
                        "generation_params": {
                            "scene_type": job.get("scene_type") or "event"
                        },
                    }
                ).execute()
            except Exception as error:
                logger.warning("Failed to insert generated_image record: %s", error)

        _update_job(
            client,
            job_id,
            {"status": "succeeded", "result_url": result_url, "error": None},
        )
    except Exception as error:
        logger.error("Media job %s failed: %s", job_id, error)
        try:
            _update_job(
                client,
                job_id,
                {"status": "failed", "error": _safe_job_error(error)},
            )
        except Exception as update_error:
            logger.error("Failed to persist media job failure %s: %s", job_id, update_error)


@router.post("/jobs", response_model=ApiResponse)
async def create_media_job(
    request: MediaJobCreate,
    background_tasks: BackgroundTasks,
    authorization: Optional[str] = Header(default=None),
):
    try:
        client = get_supabase_client()
        user_id = ensure_story_access(client, request.story_id, authorization)
        scene = _fetch_scene(client, request.story_id, request.scene_id)
        existing_url = scene.get("bgm_url" if request.media_type == "bgm" else "image_url")

        job_data = {
            "user_id": user_id,
            "story_id": str(request.story_id),
            "scene_id": str(request.scene_id),
            "media_type": request.media_type,
            "scene_type": request.scene_type,
            "prompt": _build_prompt(
                request.media_type,
                scene.get("content") or "",
                request.prompt,
            ),
            "status": "succeeded" if existing_url else "queued",
            "result_url": existing_url,
        }
        response = client.table("media_jobs").insert(job_data).execute()
        if not response.data:
            raise HTTPException(status_code=500, detail="Failed to create media job")

        job = response.data[0]
        if not existing_url:
            background_tasks.add_task(_run_media_job, job["id"])

        return ApiResponse.ok(data=_normalise_job(job, scene if existing_url else None))
    except HTTPException:
        raise
    except Exception as error:
        logger.error("Failed to create media job: %s", error)
        raise HTTPException(status_code=500, detail=str(error))


@router.get("/jobs/{job_id}", response_model=ApiResponse)
async def get_media_job(
    job_id: UUID,
    authorization: Optional[str] = Header(default=None),
):
    try:
        client = get_supabase_client()
        job_response = (
            client.table("media_jobs")
            .select("*")
            .eq("id", str(job_id))
            .single()
            .execute()
        )
        if not job_response.data:
            raise HTTPException(status_code=404, detail="Media job not found")

        job = job_response.data
        ensure_story_access(client, job["story_id"], authorization)
        scene = None
        if job.get("status") == "succeeded":
            scene = _fetch_scene(client, job["story_id"], job["scene_id"])
        return ApiResponse.ok(data=_normalise_job(job, scene))
    except HTTPException:
        raise
    except Exception as error:
        logger.error("Failed to fetch media job %s: %s", job_id, error)
        raise HTTPException(status_code=500, detail=str(error))
