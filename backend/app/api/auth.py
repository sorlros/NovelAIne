from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
from app.services.supabase_client import get_supabase_client
from app.schemas.models import ApiResponse
from datetime import datetime

router = APIRouter(prefix="/auth", tags=["auth"])

class AuthRequest(BaseModel):
    email: EmailStr
    password: str
    username: str = "Traveler"

@router.post("/signup", response_model=ApiResponse)
async def signup(request: AuthRequest):
    """Register a new user using Supabase Auth and sync to public.users table."""
    try:
        client = get_supabase_client()
        
        # 1. Register in Supabase Auth
        response = client.auth.sign_up({
            "email": request.email,
            "password": request.password,
            "options": {
                "data": {
                    "username": request.username,
                    "full_name": request.username
                }
            }
        })
        
        if not response.user:
            raise HTTPException(status_code=400, detail="Signup failed")

        # 2. Sync to public.users table
        # Note: Depending on Supabase settings, sign_up might require email confirmation.
        # However, we still attempt to create the public profile record here.
        try:
            user_data = {
                "id": response.user.id,
                "email": response.user.email,
                "username": request.username,
                "created_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat()
            }
            client.table("users").upsert(user_data).execute()
        except Exception as sync_err:
            print(f"Failed to sync user to public.users: {sync_err}")
            # We don't fail the whole request if sync fails, but log it.
            # In a production app, you'd use a DB Trigger for this.

        return ApiResponse.ok(data={
            "user": response.user.model_dump(), 
            "session": response.session.model_dump() if response.session else None
        })
        
    except Exception as e:
        print(f"Signup Error: {e}")
        return ApiResponse.fail(str(e))

@router.post("/login", response_model=ApiResponse)
async def login(request: AuthRequest):
    """Login existing user and ensure public profile exists."""
    try:
        client = get_supabase_client()
        
        # 1. Sign in via Supabase Auth
        response = client.auth.sign_in_with_password({
            "email": request.email,
            "password": request.password,
        })
        
        if not response.user:
            raise HTTPException(status_code=400, detail="Login failed")
            
        # 2. Safety check: ensure record exists in public.users
        # Sometimes users are created via Console or sync fails during signup.
        try:
            user_check = client.table("users").select("id").eq("id", response.user.id).execute()
            if not user_check.data:
                print(f"User {response.user.id} missing from public.users, creating now...")
                user_data = {
                    "id": response.user.id,
                    "email": response.user.email,
                    "username": response.user.user_metadata.get("username", "Traveler"),
                    "updated_at": datetime.now().isoformat()
                }
                client.table("users").insert(user_data).execute()
        except Exception as sync_err:
            print(f"Safety sync failed: {sync_err}")

        return ApiResponse.ok(data={
            "user": response.user.model_dump(), 
            "session": response.session.model_dump()
        })
        
    except Exception as e:
        print(f"Login Error: {e}")
        # Return friendly error message
        error_msg = str(e)
        if "Invalid login credentials" in error_msg:
            error_msg = "이메일 또는 비밀번호가 일치하지 않습니다."
        return ApiResponse.fail(error_msg)
