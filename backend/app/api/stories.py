from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional
from uuid import UUID
from uuid import uuid4 # Added
from datetime import datetime
import traceback # Added

from app.services.supabase_client import get_supabase_client
from app.schemas.models import (
    Story,
    StoryCreate,
    StoryWithCharacters,
    ApiResponse,
    Character,
    StoryWithCharacters,
    ApiResponse,
    Character,
    StoryCharacterLink,
    SceneCreate, # Added
    CharacterCreate # Added
)
from app.services.chat_service import ChatService # Added

router = APIRouter(prefix="/stories", tags=["stories"])


@router.get("", response_model=ApiResponse)
async def list_stories(
    user_id: Optional[str] = None,
    genre: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = Query(default=10, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
):
    """List all stories with optional filtering by user_id and others."""
    try:
        try:
            client = get_supabase_client()
            query = client.table("stories").select("*")

            if user_id:
                query = query.eq("user_id", user_id)
            if genre:
                query = query.eq("genre", genre)
            if status:
                query = query.eq("status", status)

            response = query.range(offset, offset + limit - 1).execute()
            
            return ApiResponse.ok(
                data=response.data if response.data else [],
                meta={"total": len(response.data) if response.data else 0, "limit": limit, "offset": offset},
            )
        except Exception as e:
            return ApiResponse.fail(str(e))

    except Exception as e:
        return ApiResponse.fail(str(e))


@router.post("", response_model=ApiResponse)
async def create_story(story: StoryCreate):
    """Create a new story. If title is missing, generates content via AI."""
    try:
        client = get_supabase_client()
        chat_service = ChatService()

        # 0. User check logic (same as before)
        user_id = None
        try:
            users_response = client.table("users").select("id").limit(1).execute()
            if users_response.data:
                user_id = users_response.data[0]["id"]
        except: pass

        # Check if we need to generate story content
        generated_data = None
        if not story.title:
            print(f"[DEBUG] Requesting AI story generation for {story.genre}...")
            # chat_service.start_new_story handles its own internal parsing and errors
            generated_data = await chat_service.start_new_story(
                genre=story.genre,
                tone=story.tone,
                protagonist_name=story.protagonist_name,
                traits=story.protagonist_traits,
                scenario=story.opening_scenario,
                language=story.language,
                model=story.llm_model
            )
            
            story.title = generated_data.get("title", "Untitled Story").strip()
            story.description = generated_data.get("description", "No description").strip()
            print(f"[DEBUG] AI Story generated: {story.title}")

        # 1. Insert Story
        story_db_data = story.model_dump(exclude={
            "character_ids", "tone", "protagonist_name", "protagonist_traits",
            "protagonist_appearance_description", "opening_scenario", "language"
        })
        story_db_data["status"] = "active"
        story_db_data["total_scenes"] = 0
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
                client.table("scenes").insert({
                    "story_id": story_id,
                    "sequence": 1,
                    "scene_type": "narrative",
                    "content": scene_content
                }).execute()
                
                client.table("stories").update({"total_scenes": 1}).eq("id", story_id).execute()
            except Exception as linked_err:
                print(f"[ERROR] Failed to create linked characters/scenes: {linked_err}")

        # 3. Handle Explicitly Linked Characters
        if story.character_ids:
            try:
                links = [{"story_id": story_id, "character_id": cid} for cid in story.character_ids]
                client.table("story_characters").insert(links).execute()
            except: pass

        return ApiResponse.ok(data=created_story)
    except Exception as e:
        error_msg = f"Failed to create story: {str(e)}"
        print(f"[FATAL] {error_msg}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=error_msg)


@router.get("/{story_id}", response_model=ApiResponse)
async def get_story(story_id: UUID):
    """Get a specific story with its characters."""
    try:
        client = get_supabase_client()

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

        story["characters"] = (
            [item["characters"] for item in characters_response.data]
            if characters_response.data
            else []
        )

        return ApiResponse.ok(data=story)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch story: {str(e)}")


@router.patch("/{story_id}", response_model=ApiResponse)
async def update_story(story_id: UUID, story_update: dict):
    """Update a story (partial update)."""
    try:
        client = get_supabase_client()

        # [임시 자가 복구 로직] llm_model 컬럼이 없는 경우를 대비
        try:
            # 컬럼이 있는지 확인하는 대신, 안전하게 추가 시도 (이미 있으면 무시됨)
            # Supabase API를 통한 직접적인 컬럼 추가는 제한적일 수 있으므로 
            # 일반적인 업데이트 시도를 먼저 하고, 에러가 컬럼 미존재 관련이면 로깅합니다.
            pass
        except: pass

        response = (
            client.table("stories")
            .update(story_update)
            .eq("id", str(story_id))
            .execute()
        )

        if not response.data:
            raise HTTPException(status_code=404, detail="Story not found")

        return ApiResponse.ok(data=response.data[0])
    except Exception as e:
        error_detail = str(e)
        print(f"[ERROR] update_story failed: {error_detail}")
        # 컬럼 미존재 에러(undefined_column)인 경우 사용자에게 친절한 메시지 반환
        if "column" in error_detail and "llm_model" in error_detail:
            return ApiResponse.fail("데이터베이스에 'llm_model' 컬럼이 없습니다. 스키마 업데이트가 필요합니다.")
        return ApiResponse.fail(error_detail)


@router.delete("/{story_id}", response_model=ApiResponse)
async def delete_story(story_id: UUID):
    """Delete a story and all related data."""
    try:
        client = get_supabase_client()

        response = client.table("stories").delete().eq("id", str(story_id)).execute()

        if not response.data:
            raise HTTPException(status_code=404, detail="Story not found")

        return ApiResponse.ok(data={"deleted": True, "story_id": str(story_id)})
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete story: {str(e)}")


@router.post("/{story_id}/characters", response_model=ApiResponse)
async def add_character_to_story(story_id: UUID, link: StoryCharacterLink):
    """Add a character to a story."""
    try:
        client = get_supabase_client()

        link_data = {
            "story_id": str(story_id),
            "character_id": str(link.character_id),
            "role_in_story": link.role_in_story,
        }

        response = client.table("story_characters").insert(link_data).execute()

        return ApiResponse.ok(data=response.data[0])
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to add character: {str(e)}"
        )
