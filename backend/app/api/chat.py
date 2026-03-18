from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Dict, Optional
from app.services.chat_service import ChatService

router = APIRouter(prefix="/chat", tags=["chat"])

from uuid import UUID
from app.services.supabase_client import get_supabase_client

class ChatRequest(BaseModel):
    story_id: UUID # Added story_id
    message: str
    history: Optional[List[Dict[str, str]]] = []

def _get_story_model(client, story_id: UUID) -> Optional[str]:
    """Helper to fetch the llm_model for a specific story."""
    try:
        story_res = client.table("stories").select("llm_model").eq("id", str(story_id)).single().execute()
        return story_res.data.get("llm_model") if story_res.data else None
    except Exception as e:
        print(f"[WARNING] Failed to fetch llm_model for story {story_id}: {e}")
        return None

@router.post("")
async def chat(request: ChatRequest):
    """일반 채팅 (한 번에 응답)"""
    try:
        client = get_supabase_client()
        model = _get_story_model(client, request.story_id)

        chat_service = ChatService()
        response = await chat_service.generate_response(request.message, request.history, model=model)
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/stream")
async def chat_stream(request: ChatRequest):
    """스트리밍 채팅 (한 글자씩 응답)"""
    client = get_supabase_client()
    model = _get_story_model(client, request.story_id)

    chat_service = ChatService()
    
    async def event_generator():
        async for chunk in chat_service.stream_generate_response(request.message, request.history, model=model):
            if chunk:
                # SSE(Server-Sent Events) 형식이 아닌 순수 텍스트 스트림으로 전송
                yield chunk

    return StreamingResponse(event_generator(), media_type="text/plain")
