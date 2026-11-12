"""Paid plans and what each plan allows per day (user_plans_20261111.sql).

The free plan writes with the standard engine, without pictures or music, within small daily limits.
The paid plan adds the premium engine, the pictures and music of the dramatic scenes, and larger limits.
"""

import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional, Tuple

from fastapi import HTTPException

from app.llm_models import PRIMARY_FAST_LLM_MODEL, PRIMARY_PRO_LLM_MODEL

logger = logging.getLogger(__name__)

FREE, PREMIUM = "free", "premium"
STORY, TURN, DIRECT_INPUT = "story", "turn", "direct_input"

KST = timezone(timedelta(hours=9))  # the counts reset on the Korean day, as in use_daily

# Uses per Korean day, except the (plan, kind) pairs in WEEKLY, which count per Korean week from Monday.
# A written action is also a scene, so it counts against both DIRECT_INPUT and TURN.
DAILY_LIMITS: Dict[str, Dict[str, int]] = {
    FREE: {STORY: 2, TURN: 10, DIRECT_INPUT: 3},
    PREMIUM: {STORY: 10, TURN: 300, DIRECT_INPUT: 50},
}
WEEKLY = {(FREE, STORY)}

PREMIUM_ONLY_MESSAGE = "유료 플랜에서 쓸 수 있는 기능입니다."
LIMIT_MESSAGES = {
    STORY: "오늘 만들 수 있는 이야기 {limit}편을 모두 만들었습니다. 내일 다시 만들거나 유료 플랜을 이용해 주세요.",
    TURN: "오늘 이어 쓸 수 있는 {limit}장면을 모두 읽었습니다. 내일 이어 가거나 유료 플랜을 이용해 주세요.",
    DIRECT_INPUT: "오늘 쓸 수 있는 직접 입력 {limit}회를 모두 썼습니다. 선택지로 이어 가거나 내일 다시 써 주세요.",
}
WEEKLY_LIMIT_MESSAGES = {
    STORY: "이번 주에 만들 수 있는 이야기 {limit}편을 모두 만들었습니다. 다음 주 월요일에 다시 만들거나 유료 플랜을 이용해 주세요.",
}


def _parse_time(value: Any) -> Optional[datetime]:
    if not value:
        return None
    parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def user_plan(client: Any, user_id: str) -> str:
    """The user's plan now: paid only with a premium row that has not expired."""
    rows = (
        client.table("user_entitlements").select("plan, expires_at").eq("user_id", str(user_id)).limit(1).execute()
    ).data or []
    if not rows or rows[0].get("plan") != PREMIUM:
        return FREE
    expires_at = _parse_time(rows[0].get("expires_at"))
    return FREE if expires_at and expires_at <= datetime.now(timezone.utc) else PREMIUM


def ensure_premium(client: Any, user_id: str) -> None:
    """403 unless the user has the paid plan now."""
    if user_plan(client, user_id) != PREMIUM:
        raise HTTPException(status_code=403, detail=PREMIUM_ONLY_MESSAGE)


def engine_for(plan: str, model: str) -> str:
    """The engine a plan may write with: the premium engine is for the paid plan."""
    return PRIMARY_FAST_LLM_MODEL if model == PRIMARY_PRO_LLM_MODEL and plan != PREMIUM else model


def daily_limit(plan: str, kind: str) -> int:
    return DAILY_LIMITS[plan][kind]


def use_daily(client: Any, user_id: str, kind: str, plan: str) -> Tuple[bool, int]:
    """Count one use of `kind` for today, against the plan's limit for the day (or the week, see WEEKLY).
    Returns whether it was allowed, and the plan's limit."""
    limit = daily_limit(plan, kind)
    function = "use_weekly" if (plan, kind) in WEEKLY else "use_daily"
    allowed = client.rpc(function, {"p_user_id": str(user_id), "p_kind": kind, "p_limit": limit}).execute().data
    return bool(allowed), limit


def give_back_daily(client: Any, user_id: str, kind: str) -> None:
    """Return a use counted for a request that gave the user nothing. Losing it is better than failing the request."""
    try:
        client.rpc("give_back_daily", {"p_user_id": str(user_id), "p_kind": kind}).execute()
    except Exception as error:
        logger.error("Could not give back a %s use of %s: %s", kind, user_id, error)


def limit_message(kind: str, limit: int, plan: str) -> str:
    messages = WEEKLY_LIMIT_MESSAGES if (plan, kind) in WEEKLY else LIMIT_MESSAGES
    return messages[kind].format(limit=limit)


def plan_summary(client: Any, user_id: str) -> Dict[str, Any]:
    """What the app shows: the plan, its limits and the uses counted against them
    (today's, or this week's for the kinds in WEEKLY)."""
    plan = user_plan(client, user_id)
    today = datetime.now(timezone.utc).astimezone(KST).date()
    monday = today - timedelta(days=today.weekday())
    rows = (
        client.table("daily_usage").select("kind, day, count").eq("user_id", str(user_id))
        .gte("day", monday.isoformat()).execute()
    ).data or []
    used = {kind: 0 for kind in DAILY_LIMITS[plan]}
    for row in rows:
        if row["kind"] in used and ((plan, row["kind"]) in WEEKLY or row["day"] == today.isoformat()):
            used[row["kind"]] += row["count"]
    return {"plan": plan, "premium": plan == PREMIUM, "limits": dict(DAILY_LIMITS[plan]), "used": used}
