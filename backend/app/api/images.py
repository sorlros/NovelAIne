from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel
from typing import Optional
from uuid import UUID
from app.services.image_service import ImageService
from app.services.auth_context import ensure_story_access
from app.services.external_errors import TEMPORARY_MESSAGE, GENERIC_MESSAGE
from app.services.supabase_client import get_supabase_client

router = APIRouter()
image_service = ImageService()

class ImageGenerateRequest(BaseModel):
    message_id: str
    prompt: str
    scene_type: str  # 'dialogue' or 'event'
    story_id: Optional[UUID] = None

@router.post("/images/generate")
async def generate_image(
    request: ImageGenerateRequest,
    authorization: Optional[str] = Header(default=None),
):
    try:
        character_appearance = None
        if request.story_id:
            client = get_supabase_client()
            ensure_story_access(client, request.story_id, authorization)
            # Fetch protagonist character linked to this story
            link_res = client.table("story_characters").select("character_id").eq("story_id", str(request.story_id)).eq("role_in_story", "protagonist").execute()
            if link_res.data:
                char_id = link_res.data[0]["character_id"]
                char_res = client.table("characters").select("appearance_description").eq("id", char_id).single().execute()
                if char_res.data and char_res.data.get("appearance_description"):
                    character_appearance = char_res.data["appearance_description"]

        image_url = await image_service.generate_anime_image(
            prompt=request.prompt,
            scene_type=request.scene_type,
            message_id=request.message_id,
            character_appearance=character_appearance
        )
        
        if not image_url:
            raise HTTPException(status_code=502, detail=TEMPORARY_MESSAGE)
            
        return {"imageUrl": image_url}
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error in image generation: {e}")
        raise HTTPException(status_code=500, detail=GENERIC_MESSAGE)
