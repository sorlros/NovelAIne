import logging
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Dict, Optional
from uuid import UUID
from app.services.chat_service import ChatService
from app.services.supabase_client import get_supabase_client

# Logger setup
logger = logging.getLogger(__name__)

router = APIRouter(prefix="/chat", tags=["chat"])

class ChatRequest(BaseModel):
    story_id: UUID # Added story_id
    message: str
    history: Optional[List[Dict[str, str]]] = []

def _get_story_metadata(client, story_id: UUID) -> Dict:
    """Helper to fetch the metadata for a specific story."""
    try:
        story_res = client.table("stories").select("llm_model, narrative_type").eq("id", str(story_id)).single().execute()
        return story_res.data if story_res.data else {}
    except Exception as e:
        logger.warning(f"Failed to fetch metadata for story {story_id}: {e}")
        return {}

@router.post("")
async def chat(request: ChatRequest):
    """일반 채팅 (한 번에 응답)"""
    try:
        client = get_supabase_client()
        metadata = _get_story_metadata(client, request.story_id)
        model = metadata.get("llm_model")
        narrative_type = metadata.get("narrative_type", "hero")

        chat_service = ChatService()
        response = await chat_service.generate_response(
            request.message, 
            request.history, 
            model=model,
            narrative_type=narrative_type # 추가
        )
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/stream")
async def chat_stream(request: ChatRequest):
    """스트리밍 채팅 (한 글자씩 응답)"""
    client = get_supabase_client()
    metadata = _get_story_metadata(client, request.story_id)
    model = metadata.get("llm_model")
    narrative_type = metadata.get("narrative_type", "hero")

    chat_service = ChatService()
    
    async def event_generator():
        async for chunk in chat_service.stream_generate_response(
            request.message, 
            request.history, 
            model=model,
            narrative_type=narrative_type # 추가
        ):
            if chunk:
                # SSE(Server-Sent Events) 형식이 아닌 순수 텍스트 스트림으로 전송
                yield chunk

    return StreamingResponse(event_generator(), media_type="text/plain")
