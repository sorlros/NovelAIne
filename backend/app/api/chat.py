import logging
from fastapi import APIRouter, Header, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from typing import List, Dict, Optional
from uuid import UUID
from app.services.chat_service import ChatService
from app.services.auth_context import ensure_story_access
from app.services.external_errors import ExternalServiceError, GENERIC_MESSAGE
from app.services.scene_service import (
    find_chat_turn_by_client_request_id,
    persist_chat_turn,
)
from app.services.supabase_client import get_supabase_client

# Logger setup
logger = logging.getLogger(__name__)

router = APIRouter(prefix="/chat", tags=["chat"])

class ChatRequest(BaseModel):
    story_id: UUID
    message: str
    history: List[Dict[str, str]] = Field(default_factory=list)
    client_request_id: Optional[str] = Field(default=None, max_length=120)

def _get_story_metadata(client, story_id: UUID) -> Dict:
    """Helper to fetch the metadata for a specific story."""
    try:
        story_res = (
            client.table("stories")
            .select("llm_model, narrative_type, user_id")
            .eq("id", str(story_id))
            .single()
            .execute()
        )
        return story_res.data if story_res.data else {}
    except Exception as e:
        logger.warning(f"Failed to fetch metadata for story {story_id}: {e}")
        return {}

@router.post("")
async def chat(
    request: ChatRequest,
    authorization: Optional[str] = Header(default=None),
):
    """일반 채팅 (한 번에 응답)"""
    try:
        client = get_supabase_client()
        authenticated_user_id = ensure_story_access(client, request.story_id, authorization)
        metadata = _get_story_metadata(client, request.story_id)
        model = metadata.get("llm_model")
        narrative_type = metadata.get("narrative_type", "hero")
        existing_turn = find_chat_turn_by_client_request_id(
            client,
            request.story_id,
            request.client_request_id,
        )
        if existing_turn:
            return {
                "response": existing_turn["ai_scene"].get("content", ""),
                "scenes": existing_turn,
                "deduplicated": True,
            }

        chat_service = ChatService()
        response = await chat_service.generate_response(
            request.message, 
            request.history, 
            model=model,
            narrative_type=narrative_type,
            story_id=request.story_id,
            user_id=authenticated_user_id or metadata.get("user_id"),
        )
        persisted = persist_chat_turn(
            client,
            request.story_id,
            user_message=request.message,
            ai_message=response,
            client_request_id=request.client_request_id,
        )
        return {"response": response, "scenes": persisted}
    except Exception as e:
        if isinstance(e, ExternalServiceError):
            raise HTTPException(status_code=502, detail=e.user_message)
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/stream")
async def chat_stream(
    request: ChatRequest,
    authorization: Optional[str] = Header(default=None),
):
    """스트리밍 채팅 (한 글자씩 응답)"""
    client = get_supabase_client()
    authenticated_user_id = ensure_story_access(client, request.story_id, authorization)
    metadata = _get_story_metadata(client, request.story_id)
    model = metadata.get("llm_model")
    narrative_type = metadata.get("narrative_type", "hero")
    existing_turn = find_chat_turn_by_client_request_id(
        client,
        request.story_id,
        request.client_request_id,
    )

    chat_service = ChatService()
    
    async def event_generator():
        if existing_turn:
            content = existing_turn["ai_scene"].get("content", "")
            if content:
                yield content
            return

        full_response = ""
        try:
            async for chunk in chat_service.stream_generate_response(
                request.message,
                request.history,
                model=model,
                narrative_type=narrative_type,
                story_id=request.story_id,
                user_id=authenticated_user_id or metadata.get("user_id"),
            ):
                if chunk:
                    full_response += chunk
                    yield chunk
        except Exception as error:
            logger.error("Stream generation failed before persistence: %s", error)
            message = error.user_message if isinstance(error, ExternalServiceError) else GENERIC_MESSAGE
            yield f"\n[STREAM_ERROR:{message}]"
            return
        if full_response.strip():
            try:
                persist_chat_turn(
                    client,
                    request.story_id,
                    user_message=request.message,
                    ai_message=full_response,
                    client_request_id=request.client_request_id,
                )
            except Exception as error:
                logger.error("Failed to persist streamed chat turn: %s", error)

    return StreamingResponse(event_generator(), media_type="text/plain")
