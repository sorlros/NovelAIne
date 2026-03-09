from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional
from uuid import UUID

from app.services.supabase_client import get_supabase_client
from app.schemas.models import (
    Scene,
    SceneCreate,
    SceneWithChoices,
    Choice,
    ChoiceCreate,
    ApiResponse,
    SceneScore,
)

router = APIRouter(prefix="/stories/{story_id}/scenes", tags=["scenes"])


@router.get("", response_model=ApiResponse)
async def list_scenes(
    story_id: UUID,
    chapter_id: Optional[UUID] = None,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
):
    """List all scenes in a story."""
    try:
        client = get_supabase_client()
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
async def create_scene(story_id: UUID, scene: SceneCreate):
    """Create a new scene in a story."""
    try:
        client = get_supabase_client()

        # Calculate scores
        scores = calculate_scene_scores(scene.content)

        scene_data = scene.model_dump(
            exclude={"choices", "generate_image", "generate_bgm"}
        )
        scene_data["story_id"] = str(story_id)
        scene_data["emotion_score"] = scores["emotion_score"]
        scene_data["importance_score"] = scores["importance_score"]
        scene_data["has_generated_image"] = scores["should_generate_image"]
        scene_data["has_generated_bgm"] = scores["should_generate_bgm"]

        # Insert scene
        scene_response = client.table("scenes").insert(scene_data).execute()

        if not scene_response.data:
            raise HTTPException(status_code=500, detail="Failed to create scene")

        created_scene = scene_response.data[0]
        scene_id = created_scene["id"]
        
        # 4. Trigger Media Generation (Async)
        if scores["should_generate_image"] or scores["should_generate_bgm"]:
            # Fetch story to get character traits
            story_res = client.table("stories").select("protagonist_traits").eq("id", str(story_id)).execute()
            traits = ""
            if story_res.data and "protagonist_traits" in story_res.data[0]:
                traits_data = story_res.data[0]["protagonist_traits"]
                traits = ", ".join(traits_data) if isinstance(traits_data, list) else str(traits_data)

            if scores["should_generate_image"]:
                from app.services.image_service import ImageService
                image_service = ImageService()
                prompt = scene.content[:200]
                await image_service.generate_anime_image(prompt, "event", scene_id, character_appearance=traits)
                
            if scores["should_generate_bgm"]:
                from app.services.audio_service import AudioService
                audio_service = AudioService()
                prompt = "epic, cinematic, emotion, instrumental, " + scene.content[:100]
                await audio_service.generate_scene_bgm(prompt, scene_id)

        created_scene = scene_response.data[0]
        scene_id = created_scene["id"]

        # Insert choices if provided
        if scene.choices:
            choices_data = [
                {**choice.model_dump(), "scene_id": scene_id}
                for choice in scene.choices
            ]
            client.table("choices").insert(choices_data).execute()

        # Update story total_scenes
        client.rpc("increment_story_scene_count", {"story_id": str(story_id)}).execute()

        return ApiResponse.ok(data=created_scene)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create scene: {str(e)}")


@router.get("/{scene_id}", response_model=ApiResponse)
async def get_scene(story_id: UUID, scene_id: UUID):
    """Get a specific scene with its choices."""
    try:
        client = get_supabase_client()

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
async def update_scene(story_id: UUID, scene_id: UUID, scene_update: dict):
    """Update a scene."""
    try:
        client = get_supabase_client()

        # Recalculate scores if content updated
        if "content" in scene_update:
            scores = calculate_scene_scores(scene_update["content"])
            scene_update.update(scores)

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
async def delete_scene(story_id: UUID, scene_id: UUID):
    """Delete a scene."""
    try:
        client = get_supabase_client()

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
async def add_choice(story_id: UUID, scene_id: UUID, choice: ChoiceCreate):
    """Add a choice to a scene."""
    try:
        client = get_supabase_client()

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
