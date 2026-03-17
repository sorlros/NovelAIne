import asyncio
from backend.app.services.supabase_client import get_supabase_client
from dotenv import load_dotenv

load_dotenv('backend/.env')

async def main():
    client = get_supabase_client()
    try:
        users = client.table("users").select("*").execute()
        print("Real users in users table:", users.data)
        
        # We can also check auth.users directly but usually we don't have access unless via service role
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    asyncio.run(main())
