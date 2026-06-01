import logging
from typing import Any, Optional
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, Query, status
from pydantic import BaseModel, Field

from app.schemas.models import ApiResponse
from app.services.auth_context import (
    ensure_story_read_access,
    get_authenticated_user_id,
)
from app.services.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/community", tags=["community"])


class CommunityCommentCreate(BaseModel):
    content: str = Field(..., min_length=1, max_length=1000)


class CommunityCommentReportCreate(BaseModel):
    reason: str = Field(default="inappropriate", max_length=500)


def _require_authenticated_user_id(client: Any, authorization: Optional[str]) -> str:
    user_id = get_authenticated_user_id(client, authorization)
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication is required",
        )
    return user_id


def _normalise_author(row: dict) -> dict:
    user_info = row.get("users") or {}
    return {
        "username": user_info.get("username") or "Traveler",
        "avatar_url": user_info.get("avatar_url"),
    }


def _fetch_engagement(
    client: Any,
    story_ids: list[str],
    user_id: Optional[str],
) -> dict[str, dict[str, Any]]:
    engagement = {
        story_id: {"like_count": 0, "comment_count": 0, "is_liked": False}
        for story_id in story_ids
    }
    if not story_ids:
        return engagement

    comments = (
        client.table("story_comments")
        .select("story_id")
        .in_("story_id", story_ids)
        .eq("is_deleted", False)
        .execute()
    )
    for comment in comments.data or []:
        story_id = str(comment.get("story_id"))
        if story_id in engagement:
            engagement[story_id]["comment_count"] += 1

    reactions = (
        client.table("story_reactions")
        .select("story_id, user_id")
        .in_("story_id", story_ids)
        .eq("reaction_type", "like")
        .execute()
    )
    for reaction in reactions.data or []:
        story_id = str(reaction.get("story_id"))
        if story_id not in engagement:
            continue
        engagement[story_id]["like_count"] += 1
        if user_id and str(reaction.get("user_id")) == user_id:
            engagement[story_id]["is_liked"] = True
    return engagement


def _normalise_feed_story(row: dict, engagement: dict[str, dict[str, Any]]) -> dict:
    story_id = str(row.get("id"))
    return {
        **row,
        "author": _normalise_author(row),
        **engagement.get(
            story_id,
            {"like_count": 0, "comment_count": 0, "is_liked": False},
        ),
    }


def _normalise_comment(row: dict) -> dict:
    return {
        "id": row.get("id"),
        "story_id": row.get("story_id"),
        "user_id": row.get("user_id"),
        "content": row.get("content"),
        "created_at": row.get("created_at"),
        "updated_at": row.get("updated_at"),
        "report_count": row.get("report_count") or 0,
        "moderation_status": row.get("moderation_status") or "visible",
        "author": _normalise_author(row),
    }


def _moderation_status_for_report_count(report_count: int) -> str:
    return "hidden" if report_count >= 3 else "visible"


@router.get("/feed", response_model=ApiResponse)
async def list_community_feed(
    genre: Optional[str] = None,
    limit: int = Query(default=20, ge=1, le=50),
    offset: int = Query(default=0, ge=0),
    authorization: Optional[str] = Header(default=None),
):
    try:
        client = get_supabase_client()
        viewer_id = get_authenticated_user_id(client, authorization)
        query = (
            client.table("stories")
            .select("*, users(username, avatar_url)")
            .eq("visibility", "public")
            .in_("status", ["active", "completed"])
        )
        if genre:
            query = query.eq("genre", genre)

        response = (
            query.order("published_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        rows = response.data or []
        story_ids = [str(row["id"]) for row in rows]
        engagement = _fetch_engagement(client, story_ids, viewer_id)
        feed = [_normalise_feed_story(row, engagement) for row in rows]
        return ApiResponse.ok(
            data=feed,
            meta={"total": len(feed), "limit": limit, "offset": offset},
        )
    except HTTPException:
        raise
    except Exception as error:
        logger.error("Failed to list community feed: %s", error)
        return ApiResponse.fail(str(error))


@router.get("/stories/{story_id}/comments", response_model=ApiResponse)
async def list_story_comments(
    story_id: UUID,
    limit: int = Query(default=30, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    authorization: Optional[str] = Header(default=None),
):
    try:
        client = get_supabase_client()
        ensure_story_read_access(client, story_id, authorization)
        response = (
            client.table("story_comments")
            .select("*, users(username, avatar_url)")
            .eq("story_id", str(story_id))
            .eq("is_deleted", False)
            .neq("moderation_status", "hidden")
            .order("created_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        comments = [_normalise_comment(row) for row in (response.data or [])]
        return ApiResponse.ok(
            data=comments,
            meta={"total": len(comments), "limit": limit, "offset": offset},
        )
    except HTTPException:
        raise
    except Exception as error:
        logger.error("Failed to list comments for story %s: %s", story_id, error)
        return ApiResponse.fail(str(error))


@router.post("/stories/{story_id}/comments", response_model=ApiResponse)
async def create_story_comment(
    story_id: UUID,
    comment: CommunityCommentCreate,
    authorization: Optional[str] = Header(default=None),
):
    try:
        client = get_supabase_client()
        user_id = _require_authenticated_user_id(client, authorization)
        ensure_story_read_access(client, story_id, authorization)
        content = comment.content.strip()
        if not content:
            raise HTTPException(status_code=400, detail="Comment cannot be empty")

        response = (
            client.table("story_comments")
            .insert({"story_id": str(story_id), "user_id": user_id, "content": content})
            .execute()
        )
        created = response.data[0]
        author_response = (
            client.table("story_comments")
            .select("*, users(username, avatar_url)")
            .eq("id", created["id"])
            .single()
            .execute()
        )
        return ApiResponse.ok(data=_normalise_comment(author_response.data))
    except HTTPException:
        raise
    except Exception as error:
        logger.error("Failed to create comment for story %s: %s", story_id, error)
        return ApiResponse.fail(str(error))


@router.delete("/comments/{comment_id}", response_model=ApiResponse)
async def delete_story_comment(
    comment_id: UUID,
    authorization: Optional[str] = Header(default=None),
):
    try:
        client = get_supabase_client()
        user_id = _require_authenticated_user_id(client, authorization)
        comment_response = (
            client.table("story_comments")
            .select("id, story_id, user_id")
            .eq("id", str(comment_id))
            .eq("is_deleted", False)
            .limit(1)
            .execute()
        )
        if not comment_response.data:
            raise HTTPException(status_code=404, detail="Comment not found")

        comment = comment_response.data[0]
        story_response = (
            client.table("stories")
            .select("user_id")
            .eq("id", comment["story_id"])
            .limit(1)
            .execute()
        )
        owner_id = str(story_response.data[0]["user_id"]) if story_response.data else None
        if str(comment["user_id"]) != user_id and owner_id != user_id:
            raise HTTPException(status_code=403, detail="Cannot delete this comment")

        (
            client.table("story_comments")
            .update({"is_deleted": True, "content": "[deleted]"})
            .eq("id", str(comment_id))
            .execute()
        )
        return ApiResponse.ok(data={"deleted": True, "comment_id": str(comment_id)})
    except HTTPException:
        raise
    except Exception as error:
        logger.error("Failed to delete comment %s: %s", comment_id, error)
        return ApiResponse.fail(str(error))


@router.post("/comments/{comment_id}/report", response_model=ApiResponse)
async def report_story_comment(
    comment_id: UUID,
    report: CommunityCommentReportCreate,
    authorization: Optional[str] = Header(default=None),
):
    try:
        client = get_supabase_client()
        user_id = _require_authenticated_user_id(client, authorization)
        comment_response = (
            client.table("story_comments")
            .select("id, story_id, user_id, is_deleted")
            .eq("id", str(comment_id))
            .limit(1)
            .execute()
        )
        if not comment_response.data:
            raise HTTPException(status_code=404, detail="Comment not found")

        comment = comment_response.data[0]
        if comment.get("is_deleted"):
            raise HTTPException(status_code=404, detail="Comment not found")
        if str(comment["user_id"]) == user_id:
            raise HTTPException(status_code=400, detail="Cannot report your own comment")

        ensure_story_read_access(client, comment["story_id"], authorization)
        existing = (
            client.table("comment_reports")
            .select("id")
            .eq("comment_id", str(comment_id))
            .eq("reporter_id", user_id)
            .limit(1)
            .execute()
        )
        if not existing.data:
            client.table("comment_reports").insert(
                {
                    "comment_id": str(comment_id),
                    "story_id": comment["story_id"],
                    "reporter_id": user_id,
                    "reason": report.reason.strip() or "inappropriate",
                }
            ).execute()

        reports = (
            client.table("comment_reports")
            .select("id")
            .eq("comment_id", str(comment_id))
            .execute()
        )
        report_count = len(reports.data or [])
        moderation_status = _moderation_status_for_report_count(report_count)
        (
            client.table("story_comments")
            .update(
                {
                    "report_count": report_count,
                    "moderation_status": moderation_status,
                }
            )
            .eq("id", str(comment_id))
            .execute()
        )
        return ApiResponse.ok(
            data={
                "comment_id": str(comment_id),
                "reported": True,
                "report_count": report_count,
                "moderation_status": moderation_status,
            }
        )
    except HTTPException:
        raise
    except Exception as error:
        logger.error("Failed to report comment %s: %s", comment_id, error)
        return ApiResponse.fail(str(error))


@router.post("/stories/{story_id}/like", response_model=ApiResponse)
async def like_story(
    story_id: UUID,
    authorization: Optional[str] = Header(default=None),
):
    try:
        client = get_supabase_client()
        user_id = _require_authenticated_user_id(client, authorization)
        ensure_story_read_access(client, story_id, authorization)
        existing = (
            client.table("story_reactions")
            .select("story_id")
            .eq("story_id", str(story_id))
            .eq("user_id", user_id)
            .eq("reaction_type", "like")
            .limit(1)
            .execute()
        )
        if not existing.data:
            client.table("story_reactions").insert(
                {
                    "story_id": str(story_id),
                    "user_id": user_id,
                    "reaction_type": "like",
                }
            ).execute()
        return ApiResponse.ok(data={"story_id": str(story_id), "is_liked": True})
    except HTTPException:
        raise
    except Exception as error:
        logger.error("Failed to like story %s: %s", story_id, error)
        return ApiResponse.fail(str(error))


@router.delete("/stories/{story_id}/like", response_model=ApiResponse)
async def unlike_story(
    story_id: UUID,
    authorization: Optional[str] = Header(default=None),
):
    try:
        client = get_supabase_client()
        user_id = _require_authenticated_user_id(client, authorization)
        ensure_story_read_access(client, story_id, authorization)
        (
            client.table("story_reactions")
            .delete()
            .eq("story_id", str(story_id))
            .eq("user_id", user_id)
            .eq("reaction_type", "like")
            .execute()
        )
        return ApiResponse.ok(data={"story_id": str(story_id), "is_liked": False})
    except HTTPException:
        raise
    except Exception as error:
        logger.error("Failed to unlike story %s: %s", story_id, error)
        return ApiResponse.fail(str(error))
