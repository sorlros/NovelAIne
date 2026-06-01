import logging
from typing import Any, Optional
from uuid import UUID

from fastapi import HTTPException, status

logger = logging.getLogger(__name__)


def extract_bearer_token(authorization: Optional[str]) -> Optional[str]:
    if not authorization:
        return None
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header",
        )
    return token.strip()


def get_authenticated_user_id(client: Any, authorization: Optional[str]) -> Optional[str]:
    token = extract_bearer_token(authorization)
    if token is None:
        return None

    try:
        response = client.auth.get_user(token)
        user = getattr(response, "user", None)
        if not user:
            raise ValueError("No user returned for token")
        return str(user.id)
    except HTTPException:
        raise
    except Exception as error:
        logger.warning("Failed to verify auth token: %s", error)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired session",
        )


def resolve_request_user_id(
    client: Any,
    authorization: Optional[str],
    requested_user_id: Optional[UUID | str],
    *,
    required: bool = True,
) -> Optional[str]:
    authenticated_user_id = get_authenticated_user_id(client, authorization)
    requested = str(requested_user_id) if requested_user_id else None

    if authenticated_user_id and requested and authenticated_user_id != requested:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Requested user does not match authenticated user",
        )
    if authenticated_user_id:
        return authenticated_user_id
    if requested:
        return requested
    if required:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication is required",
        )
    return None


def ensure_story_access(
    client: Any,
    story_id: UUID | str,
    authorization: Optional[str],
    *,
    required: bool = True,
) -> Optional[str]:
    authenticated_user_id = get_authenticated_user_id(client, authorization)
    if not authenticated_user_id:
        if required:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication is required",
            )
        return None

    response = (
        client.table("stories")
        .select("user_id")
        .eq("id", str(story_id))
        .single()
        .execute()
    )
    if not response.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Story not found")
    if str(response.data.get("user_id")) != authenticated_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Story does not belong to authenticated user",
        )
    return authenticated_user_id


def ensure_story_read_access(
    client: Any,
    story_id: UUID | str,
    authorization: Optional[str],
) -> Optional[str]:
    authenticated_user_id = get_authenticated_user_id(client, authorization)
    response = (
        client.table("stories")
        .select("user_id, visibility")
        .eq("id", str(story_id))
        .single()
        .execute()
    )
    if not response.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Story not found")

    owner_id = str(response.data.get("user_id"))
    if authenticated_user_id and owner_id == authenticated_user_id:
        return authenticated_user_id
    if response.data.get("visibility") == "public":
        return authenticated_user_id

    if not authenticated_user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication is required",
        )
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Story does not belong to authenticated user",
    )


def ensure_character_access(
    client: Any,
    character_id: UUID | str,
    authorization: Optional[str],
    *,
    required: bool = True,
) -> Optional[str]:
    authenticated_user_id = get_authenticated_user_id(client, authorization)
    if not authenticated_user_id:
        if required:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication is required",
            )
        return None

    response = (
        client.table("characters")
        .select("user_id")
        .eq("id", str(character_id))
        .single()
        .execute()
    )
    if not response.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Character not found")
    if str(response.data.get("user_id")) != authenticated_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Character does not belong to authenticated user",
        )
    return authenticated_user_id
