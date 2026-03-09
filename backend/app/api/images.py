from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.services.image_service import ImageService

router = APIRouter()
image_service = ImageService()

class ImageGenerateRequest(BaseModel):
    message_id: str
    prompt: str
    scene_type: str  # 'dialogue' or 'event'

@router.post("/images/generate")
async def generate_image(request: ImageGenerateRequest):
    try:
        image_url = await image_service.generate_anime_image(
            prompt=request.prompt,
            scene_type=request.scene_type,
            message_id=request.message_id
        )
        
        if not image_url:
            raise HTTPException(status_code=500, detail="이미지 생성 또는 업로드에 실패했습니다.")
            
        return {"imageUrl": image_url}
        
    except Exception as e:
        print(f"Error in image generation: {e}")
        raise HTTPException(status_code=500, detail=str(e))
