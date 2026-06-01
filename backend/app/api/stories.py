import logging
from fastapi import APIRouter, Header, HTTPException, Query
from typing import Optional
from uuid import UUID
from datetime import datetime, timezone

from app.services.supabase_client import get_supabase_client
from app.schemas.models import (
    StoryCreate,
    ApiResponse,
    StoryCharacterLink,
)
from app.services.chat_service import ChatService # Added
from app.services.rag_service import RagService
from app.services.auth_context import ensure_story_access, ensure_story_read_access, resolve_request_user_id
from app.services.scene_service import insert_scene_record, update_story_scene_pointer

# Logger setup
logger = logging.getLogger(__name__)

router = APIRouter(prefix="/stories", tags=["stories"])


def _normalise_public_story(row: dict) -> dict:
    user_info = row.get("users") or {}
    return {
        **row,
        "author": {
            "username": user_info.get("username") or "Traveler",
            "avatar_url": user_info.get("avatar_url"),
        },
    }


@router.get("", response_model=ApiResponse)
async def list_stories(
    user_id: Optional[str] = None,
    genre: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = Query(default=10, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    authorization: Optional[str] = Header(default=None),
):
    """List all stories with optional filtering by user_id and others."""
    try:
        try:
            client = get_supabase_client()
            resolved_user_id = resolve_request_user_id(
                client,
                authorization,
                user_id,
                required=False,
            )
            if not resolved_user_id:
                return ApiResponse.ok(data=[], meta={"total": 0, "limit": limit, "offset": offset})
            query = client.table("stories").select("*")

            query = query.eq("user_id", resolved_user_id)
            if genre:
                query = query.eq("genre", genre)
            if status:
                query = query.eq("status", status)

            response = query.range(offset, offset + limit - 1).execute()
            
            return ApiResponse.ok(
                data=response.data if response.data else [],
                meta={"total": len(response.data) if response.data else 0, "limit": limit, "offset": offset},
            )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Failed to list stories: {e}")
            return ApiResponse.fail(str(e))

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Critical error in list_stories: {e}")
        return ApiResponse.fail(str(e))


@router.get("/public", response_model=ApiResponse)
async def list_public_stories(
    genre: Optional[str] = None,
    limit: int = Query(default=20, ge=1, le=50),
    offset: int = Query(default=0, ge=0),
):
    """List public stories for Explore without exposing private user libraries."""
    try:
        client = get_supabase_client()
        query = (
            client.table("stories")
            .select("*, users(username, avatar_url)")
            .eq("visibility", "public")
            .in_("status", ["active", "completed"])
        )
        if genre:
            query = query.eq("genre", genre)

        response = (
            query.order("published_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        stories = [_normalise_public_story(row) for row in (response.data or [])]
        return ApiResponse.ok(
            data=stories,
            meta={"total": len(stories), "limit": limit, "offset": offset},
        )
    except Exception as error:
        logger.error("Failed to list public stories: %s", error)
        return ApiResponse.fail(str(error))


@router.post("", response_model=ApiResponse)
async def create_story(
    story: StoryCreate,
    authorization: Optional[str] = Header(default=None),
):
    """Create a new story. If title is missing, generates content via AI."""
    try:
        client = get_supabase_client()
        chat_service = ChatService()

        user_id = resolve_request_user_id(
            client,
            authorization,
            story.user_id,
            required=True,
        )

        # Check if we need to generate story content
        generated_data = None
        if not story.title:
            logger.info(f"Requesting AI story generation for {story.genre} (Type: {story.narrative_type})...")
            # chat_service.start_new_story handles its own internal parsing and errors
            generated_data = await chat_service.start_new_story(
                genre=story.genre,
                tone=story.tone,
                protagonist_name=story.protagonist_name,
                traits=story.protagonist_traits,
                scenario=story.opening_scenario,
                language=story.language,
                model=story.llm_model,
                narrative_type=story.narrative_type # 추가
            )
            
            story.title = generated_data.get("title", "Untitled Story").strip()
            story.description = generated_data.get("description", "No description").strip()
            logger.info(f"AI Story generated: {story.title}")

        # 1. Insert Story
        story_db_data = story.model_dump(exclude={
            "user_id", "character_ids", "tone", "protagonist_name", "protagonist_traits",
            "protagonist_appearance_description", "opening_scenario", "language"
        })
        story_db_data["status"] = "active"
        story_db_data["total_scenes"] = 0
        if story_db_data.get("visibility") == "public":
            story_db_data["published_at"] = datetime.now(timezone.utc).isoformat()
        if user_id:
            story_db_data["user_id"] = user_id
        
        # Ensure llm_model is in the data
        if "llm_model" not in story_db_data:
            story_db_data["llm_model"] = story.llm_model
            
        story_response = client.table("stories").insert(story_db_data).execute()
        
        if not story_response.data:
            raise HTTPException(status_code=500, detail="Failed to save story to DB")

        created_story = story_response.data[0]
        story_id = created_story["id"]

        # 2. Handle Generated Content (Character & Scene)
        if generated_data:
            try:
                # A. Create Protagonist
                # Use AI generated name and traits if user didn't provide them
                p_name = story.protagonist_name or generated_data.get("protagonist_name") or "주인공"
                bio = generated_data.get("protagonist_bio", "용감한 모험가")
                p_traits = story.protagonist_traits if story.protagonist_traits else generated_data.get("protagonist_traits", [])
                
                char_data = {
                    "name": p_name,
                    "description": bio,
                    "personality_traits": p_traits,
                    "appearance_description": story.protagonist_appearance_description,
                    "user_id": user_id
                }
                try:
                    embedding_text = " ".join(
                        value
                        for value in [p_name, bio, " ".join(p_traits or [])]
                        if value
                    )
                    embedding = await RagService().generate_embedding(embedding_text)
                    if embedding:
                        char_data["embedding"] = embedding
                except Exception as embedding_err:
                    logger.warning(f"Failed to generate protagonist embedding: {embedding_err}")
                
                char_response = client.table("characters").insert(char_data).execute()
                if char_response.data:
                    char_id = char_response.data[0]["id"]
                    client.table("story_characters").insert({
                        "story_id": story_id,
                        "character_id": char_id,
                        "role_in_story": "protagonist"
                    }).execute()

                # B. Create First Scene
                scene_content = generated_data.get("first_scene", "모험의 막이 오릅니다.")
                first_scene = insert_scene_record(
                    client,
                    story_id,
                    content=scene_content,
                    sequence=1,
                    scene_type="narrative",
                    role="ai",
                    has_generated_image=False,
                    has_generated_bgm=False,
                )
                update_story_scene_pointer(client, story_id, first_scene["id"], 1)
                created_story["total_scenes"] = 1
                created_story["current_scene_id"] = first_scene["id"]
            except Exception as linked_err:
                logger.error(f"Failed to create linked characters/scenes: {linked_err}")

        # 3. Handle Explicitly Linked Characters
        if story.character_ids:
            try:
                links = [{"story_id": story_id, "character_id": cid} for cid in story.character_ids]
                client.table("story_characters").insert(links).execute()
            except Exception as e:
                logger.error(f"Failed to link characters: {e}")

        return ApiResponse.ok(data=created_story)
    except HTTPException:
        raise
    except Exception as e:
        error_msg = f"Failed to create story: {str(e)}"
        logger.exception(error_msg)
        raise HTTPException(status_code=500, detail=error_msg)


@router.get("/{story_id}", response_model=ApiResponse)
async def get_story(
    story_id: UUID,
    authorization: Optional[str] = Header(default=None),
):
    """Get a specific story with its characters."""
    try:
        client = get_supabase_client()
        ensure_story_read_access(client, story_id, authorization)

        # Get story
        story_response = (
            client.table("stories")
            .select("*")
            .eq("id", str(story_id))
            .single()
            .execute()
        )

        if not story_response.data:
            raise HTTPException(status_code=404, detail="Story not found")

        story = story_response.data

        # Get linked characters
        characters_response = (
            client.table("story_characters")
            .select("character_id, role_in_story, characters(*)")
            .eq("story_id", str(story_id))
            .execute()
        )

        # 역할 정보(role_in_story)를 캐릭터 데이터 내부에 주입
        story_characters = []
        for item in characters_response.data:
            if item.get("characters"):
                char_info = item["characters"]
                char_info["role_in_story"] = item.get("role_in_story")
                story_characters.append(char_info)

        story["characters"] = story_characters

        return ApiResponse.ok(data=story)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to fetch story {story_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch story: {str(e)}")


@router.patch("/{story_id}", response_model=ApiResponse)
async def update_story(
    story_id: UUID,
    story_update: dict,
    authorization: Optional[str] = Header(default=None),
):
    """Update a story (partial update)."""
    try:
        client = get_supabase_client()
        ensure_story_access(client, story_id, authorization)
        story_update.pop("user_id", None)
        if story_update.get("visibility") == "public":
            story_update["published_at"] = datetime.now(timezone.utc).isoformat()
        elif story_update.get("visibility") == "private":
            story_update["published_at"] = None

        response = (
            client.table("stories")
            .update(story_update)
            .eq("id", str(story_id))
            .execute()
        )

        if not response.data:
            raise HTTPException(status_code=404, detail="Story not found")

        return ApiResponse.ok(data=response.data[0])
    except HTTPException:
        raise
    except Exception as e:
        error_detail = str(e)
        logger.error(f"update_story failed for {story_id}: {error_detail}")
        # 컬럼 미존재 에러(undefined_column)인 경우 사용자에게 친절한 메시지 반환
        if "column" in error_detail and "llm_model" in error_detail:
            return ApiResponse.fail("데이터베이스에 'llm_model' 컬럼이 없습니다. 스키마 업데이트가 필요합니다.")
        return ApiResponse.fail(error_detail)


@router.delete("/{story_id}", response_model=ApiResponse)
async def delete_story(
    story_id: UUID,
    authorization: Optional[str] = Header(default=None),
):
    """Delete a story and all related data."""
    try:
        client = get_supabase_client()
        ensure_story_access(client, story_id, authorization)

        response = client.table("stories").delete().eq("id", str(story_id)).execute()

        if not response.data:
            raise HTTPException(status_code=404, detail="Story not found")

        return ApiResponse.ok(data={"deleted": True, "story_id": str(story_id)})
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to delete story {story_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete story: {str(e)}")


@router.post("/{story_id}/characters", response_model=ApiResponse)
async def add_character_to_story(
    story_id: UUID,
    link: StoryCharacterLink,
    authorization: Optional[str] = Header(default=None),
):
    """Add a character to a story."""
    try:
        client = get_supabase_client()
        ensure_story_access(client, story_id, authorization)

        link_data = {
            "story_id": str(story_id),
            "character_id": str(link.character_id),
            "role_in_story": link.role_in_story,
        }

        response = client.table("story_characters").insert(link_data).execute()

        return ApiResponse.ok(data=response.data[0])
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to add character to story {story_id}: {e}")
        raise HTTPException(
            status_code=500, detail=f"Failed to add character: {str(e)}"
        )
