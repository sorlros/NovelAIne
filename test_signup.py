import asyncio
from backend.app.services.supabase_client import get_supabase_client
from dotenv import load_dotenv

load_dotenv('backend/.env')

async def main():
    client = get_supabase_client()
    try:
        response = client.auth.sign_up({
            "email": "testsignup123@example.com",
            "password": "Password123!",
            "options": {
                "data": {
                    "username": "TestUser",
                    "full_name": "Test User"
                }
            }
        })
        print("Signup response:", response)
        
        # Check if they exist in public.users
        if response.user:
            users = client.table("users").select("*").eq("id", response.user.id).execute()
            print("In public.users:", users.data)
            
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    asyncio.run(main())
