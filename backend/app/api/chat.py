from fastapi import APIRouter, HTTPException
from app.schemas.chat import ChatRequest
from app.services.chat_service import ChatService
from app.api.scenes import calculate_scene_scores
import uuid
import asyncio

router = APIRouter()
chat_service = ChatService()

@router.post("/chat")
async def chat(request: ChatRequest):
    try:
        # Request에 history 필드가 있다면 받아서 넘겨줄 수 있음 (현재 스키마엔 없음)
        ai_response = await chat_service.generate_response(request.message)
        
        # === BGM Generate Logics ===
        scores = calculate_scene_scores(ai_response)
        bgm_url = None
        
        if scores["should_generate_bgm"]:
            from app.services.audio_service import AudioService
            audio_service = AudioService()
            prompt = "epic cinematic, instrumental, " + ai_response[:100]
            # Run in background to avoid blocking user UX too much, or await if fast.
            # MusicGen might take 10-20 sec. Awaiting for now so frontend can play immediately.
            bgm_url = await audio_service.generate_scene_bgm(prompt, str(uuid.uuid4()))

        return {
            "response": ai_response,
            "bgmUrl": bgm_url
        }

    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(
            status_code=500, detail=f"AI 응답 생성 중 오류 발생: {str(e)}"
        )
    

