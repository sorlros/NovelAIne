from typing import Optional

from fastapi import APIRouter, Header, HTTPException

from app.schemas.models import ApiResponse
from app.services.auth_context import resolve_request_user_id
from app.services.plans import plan_summary
from app.services.supabase_client import get_supabase_client

router = APIRouter(prefix="/me", tags=["plans"])


@router.get("/plan", response_model=ApiResponse)
async def get_my_plan(authorization: Optional[str] = Header(default=None)):
    """The signed-in user's plan, its daily limits and today's uses:
    {"plan": "free"|"premium", "premium": bool, "limits": {story, turn, direct_input}, "used": {...}}."""
    client = get_supabase_client()
    user_id = resolve_request_user_id(client, authorization, None, required=True)
    try:
        return ApiResponse.ok(data=plan_summary(client, user_id))
    except Exception as error:
        raise HTTPException(status_code=500, detail="Failed to read the plan") from error
