import os
from typing import Final


# The two engines a reader picks: low-cost and premium. Chosen by a blind comparison of scene prose
# (2026-11-11): DeepSeek V4.1 Flash for cost, Claude Sonnet 5.5 for quality and following the brief.
PRIMARY_FAST_LLM_MODEL: Final[str] = "deepseek/deepseek-v4.1-flash"
PRIMARY_PRO_LLM_MODEL: Final[str] = "anthropic/claude-sonnet-5.5"

# The previous engines, still available: used when the primary fails.
FAST_FALLBACK_LLM_MODEL: Final[str] = "google/gemini-3.1-flash-lite"
PRO_FALLBACK_LLM_MODEL: Final[str] = "google/gemini-3.1-pro-preview"

# Stored story settings that now mean another engine. The previous primaries map to the current
# ones, so stories created with them move along (fallbacks are not normalized, so they still apply).
DEPRECATED_LLM_MODEL_REPLACEMENTS: Final[dict[str, str]] = {
    "google/gemini-2.0-flash-001": PRIMARY_FAST_LLM_MODEL,
    "google/gemini-pro-1.5": PRIMARY_PRO_LLM_MODEL,
    "google/gemini-3.1-flash-lite": PRIMARY_FAST_LLM_MODEL,
    "google/gemini-3.1-pro-preview": PRIMARY_PRO_LLM_MODEL,
}

# Both engines reason before answering by default, and the reasoning counts against max_tokens:
# long answers came back empty or cut off (measured 2026-11-11).
# DeepSeek V4.1 Flash: reasoning off. It writes scenes only (planning is PLANNING_*); with reasoning on
# it ran past 24,000 tokens on plans.
LLM_REQUEST_OPTIONS: Final[dict[str, dict]] = {
    PRIMARY_FAST_LLM_MODEL: {"reasoning": {"enabled": False}},
}
# Claude Sonnet 5.5: reasoning cannot be turned off, and lowering it broke the major-event plan
# (41 check problems instead of 0). The allowance must cover it: a plan used 15,492 tokens.
LLM_MIN_MAX_TOKENS: Final[dict[str, int]] = {
    PRIMARY_PRO_LLM_MODEL: 24000,
}
# A plan's allowance: a segment plan is about 2,500 to 6,000 tokens. Sonnet gets more (LLM_MIN_MAX_TOKENS).
PLANNING_REQUEST: Final[dict] = {"max_tokens": 16000}

# Skeleton-mode planning, apart from the engine that writes the scenes. Chosen by planning the same
# segment twice with each candidate (2026-11-11): check problems 1/0 for Gemini 3.8 Flash and 0/0 for
# Claude Sonnet 5.5 (5x the price), against 1/6 for DeepSeek V4.1 Flash, which also ran out of tokens
# with reasoning on. The major events (one plan per story) go to the stronger model.
PLANNING_FAST_LLM_MODEL: Final[str] = "google/gemini-3.8-flash"
PLANNING_PRO_LLM_MODEL: Final[str] = PRIMARY_PRO_LLM_MODEL

LLM_MODEL_FALLBACKS: Final[dict[str, str]] = {
    PRIMARY_FAST_LLM_MODEL: FAST_FALLBACK_LLM_MODEL,
    PRIMARY_PRO_LLM_MODEL: PRO_FALLBACK_LLM_MODEL,
    PLANNING_FAST_LLM_MODEL: FAST_FALLBACK_LLM_MODEL,
}


def normalize_llm_model(model: str | None) -> str:
    if not model:
        return PRIMARY_FAST_LLM_MODEL

    cleaned_model = model.strip()
    return DEPRECATED_LLM_MODEL_REPLACEMENTS.get(cleaned_model, cleaned_model)


DEFAULT_LLM_MODEL: Final[str] = normalize_llm_model(
    os.getenv("LLM_MODEL") or PRIMARY_FAST_LLM_MODEL
)


def request_for(payload: dict, model: str) -> dict:
    """The request body for one model: its own options, and an allowance large enough for its reasoning.
    You pay for the tokens used, not the allowance."""
    body = {**LLM_REQUEST_OPTIONS.get(model, {}), **payload, "model": model}  # the request's own fields win
    floor = LLM_MIN_MAX_TOKENS.get(model)
    if floor and body.get("max_tokens", 0) < floor:
        body["max_tokens"] = floor
    return body


def fallback_llm_model_for(model: str | None) -> str | None:
    normalized_model = normalize_llm_model(model)
    return LLM_MODEL_FALLBACKS.get(normalized_model)
