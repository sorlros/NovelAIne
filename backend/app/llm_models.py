import os
from typing import Final


PRIMARY_FAST_LLM_MODEL: Final[str] = "google/gemini-3.1-flash-lite"
PRIMARY_PRO_LLM_MODEL: Final[str] = "google/gemini-3.1-pro-preview"

FAST_FALLBACK_LLM_MODEL: Final[str] = "qwen/qwen3.7-plus"
PRO_FALLBACK_LLM_MODEL: Final[str] = "minimax/minimax-m3"

DEPRECATED_LLM_MODEL_REPLACEMENTS: Final[dict[str, str]] = {
    "google/gemini-2.0-flash-001": PRIMARY_FAST_LLM_MODEL,
    "google/gemini-pro-1.5": PRIMARY_PRO_LLM_MODEL,
}

LLM_MODEL_FALLBACKS: Final[dict[str, str]] = {
    PRIMARY_FAST_LLM_MODEL: FAST_FALLBACK_LLM_MODEL,
    PRIMARY_PRO_LLM_MODEL: PRO_FALLBACK_LLM_MODEL,
}


def normalize_llm_model(model: str | None) -> str:
    if not model:
        return PRIMARY_FAST_LLM_MODEL

    cleaned_model = model.strip()
    return DEPRECATED_LLM_MODEL_REPLACEMENTS.get(cleaned_model, cleaned_model)


DEFAULT_LLM_MODEL: Final[str] = normalize_llm_model(
    os.getenv("LLM_MODEL") or PRIMARY_FAST_LLM_MODEL
)


def fallback_llm_model_for(model: str | None) -> str | None:
    normalized_model = normalize_llm_model(model)
    return LLM_MODEL_FALLBACKS.get(normalized_model)
