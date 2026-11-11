"""Supabase client configuration and utilities."""

from supabase import ClientOptions, create_client, Client
import asyncio
import logging
import os
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# Supabase client instance
supabase: Optional[Client] = None


def _settings() -> tuple[str, str]:
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_KEY")

    if not supabase_url or not supabase_key:
        raise ValueError(
            "SUPABASE_URL and SUPABASE_KEY environment variables must be set"
        )
    return supabase_url, supabase_key


def get_supabase_client() -> Client:
    """Get or create Supabase client instance.

    Never sign a user in, up or refresh a session on this client: supabase-py then sends that
    user's token with every later query, so the server would act as whoever signed in last.
    Use create_auth_client() for those.
    """
    global supabase

    if supabase is None:
        supabase = create_client(*_settings())

    return supabase


def create_auth_client() -> Client:
    """A throwaway client for one sign-up, sign-in or session refresh. It keeps no session and
    starts no refresh timer, and the shared client's credentials are left untouched."""
    return create_client(*_settings(), options=ClientOptions(auto_refresh_token=False, persist_session=False))


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
