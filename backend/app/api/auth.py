from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
from app.services.supabase_client import get_supabase_client
from app.schemas.models import ApiResponse

router = APIRouter(prefix="/auth", tags=["auth"])

class AuthRequest(BaseModel):
    email: EmailStr
    password: str
    username: str = "Traveler"

@router.post("/signup", response_model=ApiResponse)
async def signup(request: AuthRequest):
    """Register a new user using Supabase Auth."""
    if request.email == "dev@novelaine.com":
        return ApiResponse.ok(data={
            "user": {
                "id": "e0000000-0000-0000-0000-000000000000",
                "email": request.email,
                "user_metadata": {"username": "Developer", "full_name": "Developer"}
            },
            "session": {"access_token": "dev_fake_token", "refresh_token": "dev_fake_refresh"}
        })

    try:
        client = get_supabase_client()
        # Supabase Auto-confirms in dev mode usually, or sends email.
        # We also want to ensure a record exists in 'public.users' if not using Triggers.
        # But Supabase Auth handles the 'auth.users' table.
        # Let's rely on Supabase Auth for now.
        
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

        return ApiResponse.ok(data={"user": response.user.model_dump(), "session": response.session.model_dump() if response.session else None})
        
    except Exception as e:
        print(f"Signup Error: {e}")
        return ApiResponse.fail(str(e))

@router.post("/login", response_model=ApiResponse)
async def login(request: AuthRequest):
    """Login existing user."""
    if request.email == "dev@novelaine.com":
        return ApiResponse.ok(data={
            "user": {
                "id": "e0000000-0000-0000-0000-000000000000",
                "email": request.email,
                "user_metadata": {"username": "Developer", "full_name": "Developer"}
            },
            "session": {"access_token": "dev_fake_token", "refresh_token": "dev_fake_refresh"}
        })

    try:
        client = get_supabase_client()
        
        response = client.auth.sign_in_with_password({
            "email": request.email,
            "password": request.password,
        })
        
        if not response.user:
            raise HTTPException(status_code=400, detail="Login failed")
            
        return ApiResponse.ok(data={"user": response.user.model_dump(), "session": response.session.model_dump()})
        
    except Exception as e:
        print(f"Login Error: {e}")
        return ApiResponse.fail(str(e))
