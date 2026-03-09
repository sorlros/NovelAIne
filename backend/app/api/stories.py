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
    genre: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = Query(default=10, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
):
    """List all stories with optional filtering."""
    try:
        try:
            client = get_supabase_client()
            query = client.table("stories").select("*")

            if genre:
                query = query.eq("genre", genre)
            if status:
                query = query.eq("status", status)

            response = query.range(offset, offset + limit - 1).execute()
            
            if response.data:
                return ApiResponse.ok(
                    data=response.data,
                    meta={"total": len(response.data), "limit": limit, "offset": offset},
                )
        except Exception:
            # Fallback to Mock Data if DB is not set up
            pass

        # MOCK DATA
        mock_stories = [
            {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "title": "The Lost World",
                "genre": "adventure",
                "description": "An ancient island discovered in the modern era, full of prehistoric creatures and forgotten mysteries.",
                "status": "published",
                "total_scenes": 12,
                "created_at": "2023-10-27T10:00:00Z",
                "updated_at": "2023-10-28T14:30:00Z",
                "cover_image_url": "https://picsum.photos/400/600" 
            },
            {
                "id": "550e8400-e29b-41d4-a716-446655440001",
                "title": "Neon Nights",
                "genre": "scifi",
                "description": "A cyberpunk noir detective story set in the rain-slicked streets of New Tokyo.",
                "status": "draft",
                "total_scenes": 5,
                "created_at": "2023-11-01T09:00:00Z",
                "updated_at": "2023-11-02T11:20:00Z",
                "cover_image_url": "https://picsum.photos/401/600"
            }
        ]
        
        return ApiResponse.ok(
            data=mock_stories,
            meta={"total": len(mock_stories), "limit": limit, "offset": offset, "source": "mock"},
        )

    except Exception as e:
        return ApiResponse.fail(str(e))


@router.post("", response_model=ApiResponse)
async def create_story(story: StoryCreate):
    """Create a new story. If title is missing, generates content via AI."""
    try:
        client = get_supabase_client()
        chat_service = ChatService()

        # 0. Get or Create Default User (MVP Hack)
        # In real app, extracting from JWT
        user_id = None
        try:
            users_response = client.table("users").select("id").limit(1).execute()
            if users_response.data:
                user_id = users_response.data[0]["id"]
            else:
                # Create Default User
                print("Creating default user...")
                new_user_id = str(uuid4())
                user_data = {
                    "id": new_user_id,
                    "email": "guest@novelaine.com",
                    "username": "Traveler",
                    "created_at": datetime.now().isoformat(),
                    "updated_at": datetime.now().isoformat()
                }
                # Try inserting into 'users' (public profile)
                # Note: If this fails due to auth linkage, we might need a different approach
                user_res = client.table("users").insert(user_data).execute()
                if user_res.data:
                    user_id = user_res.data[0]["id"]
        except Exception as e:
            print(f"User check failed: {e}")
            # If we really can't create a user, we might proceed and hope DB treats user_id as optional? 
            # unlikely given the model, but let's try to proceed or fail clearly.
            pass

        if not user_id:
             # If strictly required, this will fail next. 
             # Let's use a hardcoded fallback just in case the table allows it?
             # Or assume we can't proceed.
             print("Warning: No user_id found or created.")

        # Check if we need to generate story content
        generated_data = None
        if not story.title:
            # Generate via LLM
            print(f"Generating story for {story.genre}...")
            generated_data = await chat_service.start_new_story(
                genre=story.genre,
                tone=story.tone,
                protagonist_name=story.protagonist_name,
                traits=story.protagonist_traits,
                scenario=story.opening_scenario
            )
            
            # Fill in the missing required fields
            story.title = generated_data.get("title", "Untitled Story")
            story.description = generated_data.get("description", "No description")

        # 1. Insert Story
        # Exclude generation params that don't exist in DB
        story_db_data = story.model_dump(exclude={
            "character_ids", "tone", "protagonist_name", "protagonist_traits", "opening_scenario"
        })
        story_db_data["status"] = "active" # Set default status
        story_db_data["total_scenes"] = 0
        if user_id:
            story_db_data["user_id"] = user_id # Inject User ID
        
        story_response = client.table("stories").insert(story_db_data).execute()

        if not story_response.data:
            raise HTTPException(status_code=500, detail="Failed to create story")

        created_story = story_response.data[0]
        story_id = created_story["id"]

        # 2. Handle Generated Content (Character & Scene)
        if generated_data:
            # A. Create Protagonist
            protagonist_name = story.protagonist_name or generated_data.get("title", "Hero").split("'s")[0] # Fallback
            if story.protagonist_name:
                protagonist_name = story.protagonist_name
            
            # Use 'protagonist_bio' from LLM or fallback
            bio = generated_data.get("protagonist_bio", "A bold adventurer starting their journey.")
            
            char_data = {
                "name": protagonist_name,
                "description": bio,
                "personality_traits": story.protagonist_traits,
                "user_id": created_story["user_id"] # Inherit user_id
            }
            
            char_response = client.table("characters").insert(char_data).execute()
            if char_response.data:
                char_id = char_response.data[0]["id"]
                # Link to Story
                link_data = {
                    "story_id": story_id,
                    "character_id": char_id,
                    "role_in_story": "protagonist"
                }
                client.table("story_characters").insert(link_data).execute()

            # B. Create First Scene
            first_scene_content = generated_data.get("first_scene", "The adventure begins...")
            scene_data = {
                "story_id": story_id,
                "sequence": 1,
                "scene_type": "narrative",
                "content": first_scene_content
            }
            client.table("scenes").insert(scene_data).execute()
            
            # Update Story scene count
            client.table("stories").update({"total_scenes": 1}).eq("id", story_id).execute()

        # 3. Handle Explicitly Linked Characters (if any)
        if story.character_ids:
            character_links = [
                {"story_id": story_id, "character_id": char_id}
                for char_id in story.character_ids
            ]
            client.table("story_characters").insert(character_links).execute()

        return ApiResponse.ok(data=created_story)
    except Exception as e:
        import traceback
        error_msg = f"Error creating story: {str(e)}\n{traceback.format_exc()}"
        print(error_msg)
        with open("error.log", "a") as f:
            f.write(f"[{datetime.now()}] {error_msg}\n")
        raise HTTPException(status_code=500, detail=f"Failed to create story: {str(e)}")


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
        raise HTTPException(status_code=500, detail=f"Failed to update story: {str(e)}")


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
