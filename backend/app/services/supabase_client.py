"""Supabase client configuration and utilities."""

from supabase import create_client, Client
import asyncio
import logging
import os
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# Supabase client instance
supabase: Optional[Client] = None


def get_supabase_client() -> Client:
    """Get or create Supabase client instance."""
    global supabase

    if supabase is None:
        supabase_url = os.getenv("SUPABASE_URL")
        supabase_key = os.getenv("SUPABASE_KEY")

        if not supabase_url or not supabase_key:
            raise ValueError(
                "SUPABASE_URL and SUPABASE_KEY environment variables must be set"
            )

        supabase = create_client(supabase_url, supabase_key)

    return supabase


async def check_connection() -> bool:
    """Check if Supabase connection is working."""
    client = get_supabase_client()

    async def execute_health_query() -> None:
        await asyncio.wait_for(
            asyncio.to_thread(
                lambda: client.table("stories").select("id").limit(1).execute()
            ),
            timeout=8.0,
        )

    for attempt in range(3):
        try:
            await execute_health_query()
            return True
        except Exception as error:
            error_preview = str(error)[:300]
            logger.warning(
                "Supabase connection check failed. attempt=%s error=%s",
                attempt + 1,
                error_preview,
            )
            if attempt < 2:
                await asyncio.sleep(0.5 * (attempt + 1))

    return False
