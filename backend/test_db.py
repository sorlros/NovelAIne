import asyncio
import os
from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

async def main():
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_KEY")
    
    if not url or not key:
        print("Missing Credentials")
        return

    supabase = create_client(url, key)
    
    try:
        # Try to get users from public.users table as per model
        print("Fetching users from public.users...")
        response = supabase.table("users").select("*").limit(1).execute()
        print(f"Users response: {response.data}")
        
        if response.data:
            print(f"Found User ID: {response.data[0]['id']}")
        else:
            print("No users found in public.users")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(main())
