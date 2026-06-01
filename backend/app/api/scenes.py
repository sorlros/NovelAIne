import logging
from fastapi import APIRouter, Body, Header, HTTPException, Query
from typing import List, Optional
from uuid import UUID

from app.services.supabase_client import get_supabase_client
from app.services.chat_service import ChatService
from app.services.auth_context import ensure_story_access, ensure_story_read_access
from app.services.scene_service import insert_scene_record, update_story_scene_pointer
from app.schemas.models import (
    SceneCreate,
    ChoiceCreate,
    ApiResponse,
)

router = APIRouter(prefix="/stories/{story_id}/scenes", tags=["scenes"])
logger = logging.getLogger(__name__)

@router.post("/analyze", response_model=ApiResponse)
async def analyze_scene(
    story_id: UUID,
    content: str = Body(..., embed=True),
    character_names: List[str] = Body(..., embed=True),
    authorization: Optional[str] = Header(default=None),
):
    """Analyze a scene for character presence and importance."""
    try:
        chat_service = ChatService()
        ensure_story_read_access(get_supabase_client(), story_id, authorization)
        result = await chat_service.analyze_scene_characters(content, character_names)
        return ApiResponse.ok(data=result)
    except Exception as e:
        return ApiResponse.fail(str(e))


@router.get("", response_model=ApiResponse)
async def list_scenes(
    story_id: UUID,
    chapter_id: Optional[UUID] = None,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    authorization: Optional[str] = Header(default=None),
):
    """List all scenes in a story."""
    try:
        client = get_supabase_client()
        ensure_story_read_access(client, story_id, authorization)
        query = client.table("scenes").select("*").eq("story_id", str(story_id))

        if chapter_id:
            query = query.eq("chapter_id", str(chapter_id))

        response = query.order("sequence").range(offset, offset + limit - 1).execute()

        return ApiResponse.ok(
            data=response.data,
            meta={"total": len(response.data), "limit": limit, "offset": offset},
        )
    except Exception as e:
        return ApiResponse.fail(str(e))


@router.post("", response_model=ApiResponse)
async def create_scene(
    story_id: UUID,
    scene: SceneCreate,
    authorization: Optional[str] = Header(default=None),
):
    """Create a new scene in a story."""
    try:
        client = get_supabase_client()
        ensure_story_access(client, story_id, authorization)

        scores = calculate_scene_scores(scene.content)
        should_generate_image = scene.generate_image or scores["should_generate_image"]
        should_generate_bgm = scene.generate_bgm or scores["should_generate_bgm"]

        created_scene = insert_scene_record(
            client,
            story_id,
            content=scene.content,
            sequence=scene.sequence,
            scene_type=scene.scene_type,
            role=scene.role,
            chapter_id=scene.chapter_id,
            emotion_score=scores["emotion_score"],
            importance_score=scores["importance_score"],
            has_generated_image=False,
            has_generated_bgm=False,
        )
        scene_id = created_scene["id"]

        image_url = None
        bgm_url = None
        if should_generate_image or should_generate_bgm:
            if should_generate_image:
                from app.services.image_service import ImageService

                image_service = ImageService()
                prompt = scene.content[:200]
                image_url = await image_service.generate_anime_image(prompt, "event", scene_id)
                
            if should_generate_bgm:
                from app.services.audio_service import AudioService

                audio_service = AudioService()
                prompt = "epic, cinematic, emotion, instrumental, " + scene.content[:100]
                bgm_url = await audio_service.generate_scene_bgm(prompt, scene_id)
                if bgm_url:
                    try:
                        client.table("generated_bgms").insert(
                            {
                                "scene_id": scene_id,
                                "prompt": prompt,
                                "audio_url": bgm_url,
                                "storage_path": bgm_url,
                                "mood": "cinematic",
                            }
                        ).execute()
                    except Exception as error:
                        logger.warning("Failed to insert generated_bgm record: %s", error)

            update_data = {}
            if image_url:
                update_data["image_url"] = image_url
                update_data["has_generated_image"] = True
            if bgm_url:
                update_data["bgm_url"] = bgm_url
                update_data["has_generated_bgm"] = True
            if update_data:
                try:
                    response = client.table("scenes").update(update_data).eq("id", scene_id).execute()
                    if response.data:
                        created_scene = response.data[0]
                except Exception:
                    fallback_update = {
                        key: value
                        for key, value in update_data.items()
                        if key not in {"image_url", "bgm_url"}
                    }
                    if fallback_update:
                        client.table("scenes").update(fallback_update).eq("id", scene_id).execute()

        # Insert choices if provided
        if scene.choices:
            choices_data = [
                {**choice.model_dump(), "scene_id": scene_id}
                for choice in scene.choices
            ]
            client.table("choices").insert(choices_data).execute()

        update_story_scene_pointer(
            client,
            story_id,
            scene_id=scene_id,
            total_scenes=int(created_scene.get("sequence") or 1),
        )

        return ApiResponse.ok(data=created_scene)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create scene: {str(e)}")


@router.get("/{scene_id}", response_model=ApiResponse)
async def get_scene(
    story_id: UUID,
    scene_id: UUID,
    authorization: Optional[str] = Header(default=None),
):
    """Get a specific scene with its choices."""
    try:
        client = get_supabase_client()
        ensure_story_read_access(client, story_id, authorization)

        # Get scene
        scene_response = (
            client.table("scenes")
            .select("*")
            .eq("id", str(scene_id))
            .single()
            .execute()
        )

        if not scene_response.data:
            raise HTTPException(status_code=404, detail="Scene not found")

        scene = scene_response.data

        # Get choices
        choices_response = (
            client.table("choices")
            .select("*")
            .eq("scene_id", str(scene_id))
            .order("sequence")
            .execute()
        )
        scene["choices"] = choices_response.data if choices_response.data else []

        return ApiResponse.ok(data=scene)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch scene: {str(e)}")


@router.patch("/{scene_id}", response_model=ApiResponse)
async def update_scene(
    story_id: UUID,
    scene_id: UUID,
    scene_update: dict,
    authorization: Optional[str] = Header(default=None),
):
    """Update a scene."""
    try:
        client = get_supabase_client()
        ensure_story_access(client, story_id, authorization)

        # Recalculate scores if content updated
        if "content" in scene_update:
            scores = calculate_scene_scores(scene_update["content"])
            scene_update["emotion_score"] = scores["emotion_score"]
            scene_update["importance_score"] = scores["importance_score"]

        response = (
            client.table("scenes")
            .update(scene_update)
            .eq("id", str(scene_id))
            .execute()
        )

        if not response.data:
            raise HTTPException(status_code=404, detail="Scene not found")

        return ApiResponse.ok(data=response.data[0])
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update scene: {str(e)}")


@router.delete("/{scene_id}", response_model=ApiResponse)
async def delete_scene(
    story_id: UUID,
    scene_id: UUID,
    authorization: Optional[str] = Header(default=None),
):
    """Delete a scene."""
    try:
        client = get_supabase_client()
        ensure_story_access(client, story_id, authorization)

        response = client.table("scenes").delete().eq("id", str(scene_id)).execute()

        if not response.data:
            raise HTTPException(status_code=404, detail="Scene not found")

        # Update story total_scenes
        client.rpc("decrement_story_scene_count", {"story_id": str(story_id)}).execute()

        return ApiResponse.ok(data={"deleted": True, "scene_id": str(scene_id)})
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete scene: {str(e)}")


@router.post("/{scene_id}/choices", response_model=ApiResponse)
async def add_choice(
    story_id: UUID,
    scene_id: UUID,
    choice: ChoiceCreate,
    authorization: Optional[str] = Header(default=None),
):
    """Add a choice to a scene."""
    try:
        client = get_supabase_client()
        ensure_story_access(client, story_id, authorization)

        choice_data = choice.model_dump()
        choice_data["scene_id"] = str(scene_id)

        response = client.table("choices").insert(choice_data).execute()

        return ApiResponse.ok(data=response.data[0])
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to add choice: {str(e)}")


def calculate_scene_scores(content: str) -> dict:
    """Calculate emotion and importance scores for scene content."""
    emotion_keywords = [
        "death",
        "love",
        "betrayal",
        "victory",
        "tragedy",
        "슬픔",
        "기쁨",
        "분노",
        "사랑",
        "죽음",
    ]
    importance_keywords = [
        "choice",
        "decision",
        "discovery",
        "revelation",
        "선택",
        "결정",
        "발견",
        "전환점",
    ]

    content_lower = content.lower()

    emotion_count = sum(1 for kw in emotion_keywords if kw in content_lower)
    importance_count = sum(1 for kw in importance_keywords if kw in content_lower)

    emotion_score = min(emotion_count / 3, 1.0)  # Normalize to 0-1
    importance_score = min(importance_count / 2, 1.0)

    return {
        "emotion_score": emotion_score,
        "importance_score": importance_score,
        "should_generate_image": emotion_score > 0.5 or importance_score > 0.6,
        "should_generate_bgm": emotion_score > 0.3,
    }
