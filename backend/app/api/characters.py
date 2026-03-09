from fastapi import APIRouter, HTTPException, Query, UploadFile, File
from typing import List, Optional
from uuid import UUID
import uuid as uuid_module

from app.services.supabase_client import get_supabase_client
from app.schemas.models import Character, CharacterCreate, ApiResponse

router = APIRouter(prefix="/characters", tags=["characters"])


@router.get("", response_model=ApiResponse)
async def list_characters(
    limit: int = Query(default=10, ge=1, le=100), offset: int = Query(default=0, ge=0)
):
    """List all characters."""
    try:
        client = get_supabase_client()
        response = (
            client.table("characters")
            .select("*")
            .range(offset, offset + limit - 1)
            .execute()
        )

        return ApiResponse.ok(
            data=response.data,
            meta={"total": len(response.data), "limit": limit, "offset": offset},
        )
    except Exception as e:
        return ApiResponse.fail(str(e))


@router.post("", response_model=ApiResponse)
async def create_character(character: CharacterCreate):
    """Create a new character."""
    try:
        client = get_supabase_client()

        character_data = character.model_dump()
        response = client.table("characters").insert(character_data).execute()

        if not response.data:
            raise HTTPException(status_code=500, detail="Failed to create character")

        return ApiResponse.ok(data=response.data[0])
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to create character: {str(e)}"
        )


@router.get("/{character_id}", response_model=ApiResponse)
async def get_character(character_id: UUID):
    """Get a specific character."""
    try:
        client = get_supabase_client()
        response = (
            client.table("characters")
            .select("*")
            .eq("id", str(character_id))
            .single()
            .execute()
        )

        if not response.data:
            raise HTTPException(status_code=404, detail="Character not found")

        return ApiResponse.ok(data=response.data)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to fetch character: {str(e)}"
        )


@router.patch("/{character_id}", response_model=ApiResponse)
async def update_character(character_id: UUID, character_update: dict):
    """Update a character."""
    try:
        client = get_supabase_client()
        response = (
            client.table("characters")
            .update(character_update)
            .eq("id", str(character_id))
            .execute()
        )

        if not response.data:
            raise HTTPException(status_code=404, detail="Character not found")

        return ApiResponse.ok(data=response.data[0])
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to update character: {str(e)}"
        )


@router.delete("/{character_id}", response_model=ApiResponse)
async def delete_character(character_id: UUID):
    """Delete a character."""
    try:
        client = get_supabase_client()
        response = (
            client.table("characters").delete().eq("id", str(character_id)).execute()
        )

        if not response.data:
            raise HTTPException(status_code=404, detail="Character not found")

        return ApiResponse.ok(data={"deleted": True, "character_id": str(character_id)})
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to delete character: {str(e)}"
        )
@router.post("/{character_id}/upload-image", response_model=ApiResponse)
async def upload_character_image(
    character_id: UUID,
    file: UploadFile = File(...),
):
    """Upload an image for a character and save the public URL."""
    try:
        client = get_supabase_client()

        # Read file content
        file_content = await file.read()
        
        # Build a unique filename in Supabase Storage
        extension = (file.filename or "img.jpg").rsplit(".", 1)[-1].lower()
        storage_path = f"{character_id}/{uuid_module.uuid4()}.{extension}"
        bucket_name = "character-avatars"

        # Upload to Supabase Storage bucket
        client.storage.from_(bucket_name).upload(
            path=storage_path,
            file=file_content,
            file_options={"content-type": file.content_type or "image/jpeg"},
        )

        # Get the public URL
        public_url = client.storage.from_(bucket_name).get_public_url(storage_path)

        # Update the character's image_url column
        response = (
            client.table("characters")
            .update({"image_url": public_url})
            .eq("id", str(character_id))
            .execute()
        )

        if not response.data:
            raise HTTPException(status_code=404, detail="Character not found")

        return ApiResponse.ok(data={"image_url": public_url})

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to upload image: {str(e)}"
        )
