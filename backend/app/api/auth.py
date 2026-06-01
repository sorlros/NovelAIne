from datetime import datetime
from typing import Any

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, EmailStr, Field

from app.schemas.models import ApiResponse
from app.services.supabase_client import get_supabase_client

router = APIRouter(prefix="/auth", tags=["auth"])


class AuthRequest(BaseModel):
    email: EmailStr
    password: str
    username: str = "Traveler"


class RefreshRequest(BaseModel):
    refresh_token: str = Field(..., min_length=1)


def _auth_payload(response: Any) -> dict:
    return {
        "user": response.user.model_dump(),
        "session": response.session.model_dump() if response.session else None,
    }


def _friendly_auth_error(error: Exception) -> str:
    error_message = str(error)
    if "Invalid login credentials" in error_message:
        return "이메일 또는 비밀번호가 일치하지 않습니다."
    if "Invalid Refresh Token" in error_message or "refresh token" in error_message:
        return "로그인 세션이 만료되었습니다. 다시 로그인해 주세요."
    return error_message


def _sync_public_user_profile(
    client: Any,
    user: Any,
    username: str | None = None,
) -> None:
    metadata = user.user_metadata or {}
    profile_username = username or metadata.get("username", "Traveler")
    user_data = {
        "id": user.id,
        "email": user.email,
        "username": profile_username,
        "updated_at": datetime.now().isoformat(),
    }
    client.table("users").upsert(user_data).execute()


@router.post("/signup", response_model=ApiResponse)
async def signup(request: AuthRequest):
    """Register a new user using Supabase Auth and sync to public.users."""
    try:
        client = get_supabase_client()
        response = client.auth.sign_up(
            {
                "email": request.email,
                "password": request.password,
                "options": {
                    "data": {
                        "username": request.username,
                        "full_name": request.username,
                    }
                },
            }
        )
        if not response.user:
            raise HTTPException(status_code=400, detail="Signup failed")

        try:
            _sync_public_user_profile(client, response.user, request.username)
        except Exception as sync_err:
            print(f"Failed to sync user to public.users: {sync_err}")

        return ApiResponse.ok(data=_auth_payload(response))
    except Exception as e:
        print(f"Signup Error: {e}")
        return ApiResponse.fail(_friendly_auth_error(e))


@router.post("/login", response_model=ApiResponse)
async def login(request: AuthRequest):
    """Login existing user and ensure public profile exists."""
    try:
        client = get_supabase_client()
        response = client.auth.sign_in_with_password(
            {
                "email": request.email,
                "password": request.password,
            }
        )
        if not response.user:
            raise HTTPException(status_code=400, detail="Login failed")

        try:
            user_check = (
                client.table("users").select("id").eq("id", response.user.id).execute()
            )
            if not user_check.data:
                print(f"User {response.user.id} missing from public.users, creating now")
                _sync_public_user_profile(client, response.user)
        except Exception as sync_err:
            print(f"Safety sync failed: {sync_err}")

        return ApiResponse.ok(data=_auth_payload(response))
    except Exception as e:
        print(f"Login Error: {e}")
        return ApiResponse.fail(_friendly_auth_error(e))


@router.post("/refresh", response_model=ApiResponse)
async def refresh_session(request: RefreshRequest):
    """Refresh an expired or nearly expired Supabase auth session."""
    try:
        client = get_supabase_client()
        response = client.auth.refresh_session(request.refresh_token)
        if not response.user or not response.session:
            raise HTTPException(status_code=401, detail="Session refresh failed")

        try:
            _sync_public_user_profile(client, response.user)
        except Exception as sync_err:
            print(f"Refresh profile sync failed: {sync_err}")

        return ApiResponse.ok(data=_auth_payload(response))
    except Exception as e:
        print(f"Refresh Error: {e}")
        return ApiResponse.fail(_friendly_auth_error(e))


@router.post("/logout", response_model=ApiResponse)
async def logout(authorization: str | None = Header(default=None)):
    """Best-effort server-side sign out for the current access token."""
    if not authorization or not authorization.startswith("Bearer "):
        return ApiResponse.ok(data={"revoked": False})

    access_token = authorization.removeprefix("Bearer ").strip()
    if not access_token:
        return ApiResponse.ok(data={"revoked": False})

    try:
        client = get_supabase_client()
        client.auth.admin.sign_out(access_token, "global")
        return ApiResponse.ok(data={"revoked": True})
    except Exception as e:
        print(f"Logout revoke failed: {e}")
        return ApiResponse.ok(data={"revoked": False})
