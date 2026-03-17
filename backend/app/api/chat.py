from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Dict, Optional
from app.services.chat_service import ChatService

router = APIRouter(prefix="/chat", tags=["chat"])

class ChatRequest(BaseModel):
    message: str
    history: Optional[List[Dict[str, str]]] = []

@router.post("")
async def chat(request: ChatRequest):
    """일반 채팅 (한 번에 응답)"""
    try:
        chat_service = ChatService()
        response = await chat_service.generate_response(request.message, request.history)
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/stream")
async def chat_stream(request: ChatRequest):
    """스트리밍 채팅 (한 글자씩 응답)"""
    chat_service = ChatService()
    
    async def event_generator():
        async for chunk in chat_service.stream_generate_response(request.message, request.history):
            if chunk:
                # SSE(Server-Sent Events) 형식이 아닌 순수 텍스트 스트림으로 전송
                yield chunk

    return StreamingResponse(event_generator(), media_type="text/plain")
