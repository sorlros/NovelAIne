import logging
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

from app.schemas.models import ApiResponse
from app.services.audio_service import AudioService
from app.services.auth_context import ensure_story_access
from app.services.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/audio", tags=["audio"])


class BgmGenerateRequest(BaseModel):
    story_id: UUID
    scene_id: UUID
    prompt: Optional[str] = Field(default=None, max_length=1000)


def _build_bgm_prompt(scene_content: str, requested_prompt: Optional[str]) -> str:
    if requested_prompt and requested_prompt.strip():
        return requested_prompt.strip()
    return (
        "cinematic instrumental background music, subtle loop, emotional, "
        f"{scene_content[:400]}"
    )


@router.post("/bgm/generate", response_model=ApiResponse)
async def generate_scene_bgm(
    request: BgmGenerateRequest,
    authorization: Optional[str] = Header(default=None),
):
    """Generate BGM for a scene and persist the public audio URL."""
    try:
        client = get_supabase_client()
        ensure_story_access(client, request.story_id, authorization)

        scene_response = (
            client.table("scenes")
            .select("id, story_id, content, bgm_url")
            .eq("id", str(request.scene_id))
            .eq("story_id", str(request.story_id))
            .single()
            .execute()
        )
        if not scene_response.data:
            raise HTTPException(status_code=404, detail="Scene not found")

        scene = scene_response.data
        if scene.get("bgm_url"):
            return ApiResponse.ok(data=scene)

        prompt = _build_bgm_prompt(scene.get("content") or "", request.prompt)
        bgm_url = await AudioService().generate_scene_bgm(
            prompt=prompt,
            scene_id=str(request.scene_id),
        )
        if not bgm_url:
            raise HTTPException(status_code=502, detail="BGM generation failed")

        update_data = {"bgm_url": bgm_url, "has_generated_bgm": True}
        scene_update = (
            client.table("scenes")
            .update(update_data)
            .eq("id", str(request.scene_id))
            .execute()
        )
        updated_scene = scene_update.data[0] if scene_update.data else {**scene, **update_data}

        try:
            client.table("generated_bgms").insert(
                {
                    "scene_id": str(request.scene_id),
                    "prompt": prompt,
                    "audio_url": bgm_url,
                    "storage_path": bgm_url,
                    "mood": "cinematic",
                }
            ).execute()
        except Exception as error:
            logger.warning("Failed to insert generated_bgm record: %s", error)

        return ApiResponse.ok(data=updated_scene)
    except HTTPException:
        raise
    except Exception as error:
        logger.error("Failed to generate BGM for scene %s: %s", request.scene_id, error)
        raise HTTPException(status_code=500, detail=str(error))
