from fastapi import APIRouter, Header, HTTPException, Query, UploadFile, File
from typing import List, Optional
from uuid import UUID
import uuid as uuid_module
import logging

from app.services.supabase_client import get_supabase_client
from app.services.rag_service import RagService
from app.services.auth_context import ensure_character_access, resolve_request_user_id
from app.schemas.models import Character, CharacterCreate, ApiResponse

router = APIRouter(prefix="/characters", tags=["characters"])
logger = logging.getLogger(__name__)


async def _generate_character_embedding(character_data: dict) -> list[float]:
    searchable_text = " ".join(
        str(value)
        for value in [
            character_data.get("name"),
            character_data.get("description"),
            " ".join(character_data.get("personality_traits") or []),
            character_data.get("background_story"),
        ]
        if value
    )
    if not searchable_text.strip():
        return []

    try:
        return await RagService().generate_embedding(searchable_text)
    except Exception as error:
        logger.warning("Failed to generate character embedding: %s", error)
        return []


@router.get("", response_model=ApiResponse)
async def list_characters(
    user_id: Optional[str] = None,
    limit: int = Query(default=10, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    authorization: Optional[str] = Header(default=None),
):
    """List all characters with optional user_id filtering."""
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
        query = client.table("characters").select("*")
        
        query = query.eq("user_id", resolved_user_id)
            
        response = query.range(offset, offset + limit - 1).execute()

        return ApiResponse.ok(
            data=response.data,
            meta={"total": len(response.data), "limit": limit, "offset": offset},
        )
    except HTTPException:
        raise
    except Exception as e:
        return ApiResponse.fail(str(e))


@router.post("", response_model=ApiResponse)
async def create_character(
    character: CharacterCreate,
    authorization: Optional[str] = Header(default=None),
):
    """Create a new character."""
    try:
        client = get_supabase_client()

        character_data = character.model_dump(exclude_none=True)
        character_data["user_id"] = resolve_request_user_id(
            client,
            authorization,
            character_data.get("user_id"),
            required=True,
        )

        embedding = await _generate_character_embedding(character_data)
        if embedding:
            character_data["embedding"] = embedding

        response = client.table("characters").insert(character_data).execute()

        if not response.data:
            raise HTTPException(status_code=500, detail="Failed to create character")

        return ApiResponse.ok(data=response.data[0])
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to create character: {str(e)}"
        )


@router.get("/{character_id}", response_model=ApiResponse)
async def get_character(
    character_id: UUID,
    authorization: Optional[str] = Header(default=None),
):
    """Get a specific character."""
    try:
        client = get_supabase_client()
        ensure_character_access(client, character_id, authorization)
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
async def update_character(
    character_id: UUID,
    character_update: dict,
    authorization: Optional[str] = Header(default=None),
):
    """Update a character."""
    try:
        client = get_supabase_client()
        ensure_character_access(client, character_id, authorization)
        if any(
            key in character_update
            for key in ["name", "description", "personality_traits", "background_story"]
        ):
            current = (
                client.table("characters")
                .select("name, description, personality_traits, background_story")
                .eq("id", str(character_id))
                .single()
                .execute()
            )
            merged_data = {**(current.data or {}), **character_update}
            embedding = await _generate_character_embedding(merged_data)
            if embedding:
                character_update["embedding"] = embedding

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
async def delete_character(
    character_id: UUID,
    authorization: Optional[str] = Header(default=None),
):
    """Delete a character."""
    try:
        client = get_supabase_client()
        ensure_character_access(client, character_id, authorization)
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
    authorization: Optional[str] = Header(default=None),
):
    """Upload an image for a character and save the public URL."""
    try:
        client = get_supabase_client()
        ensure_character_access(client, character_id, authorization)

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
