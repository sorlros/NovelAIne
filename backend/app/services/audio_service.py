import base64
import json
import logging
import os
from typing import Iterable, Optional

import httpx

from app.services.external_errors import error_from_response, with_timeout_retry
from app.services.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)

MUSIC_MODEL = "google/lyria-3-clip-preview"  # a 30-second clip, $0.04 (2026-11)
CHAT_API_URL = "https://openrouter.ai/api/v1/chat/completions"
INSTRUMENTAL = "Instrumental background music only, no vocals, no lyrics. A 30-second piece for a scene in a novel."


def audio_from_stream(lines: Iterable[str]) -> bytes:
    """The audio of a streamed OpenRouter chat completion: base64 pieces in choices[].delta.audio.data."""
    pieces = []
    for line in lines:
        if not line.startswith("data: ") or line.strip() == "data: [DONE]":
            continue
        for choice in json.loads(line[6:]).get("choices") or []:
            data = ((choice.get("delta") or {}).get("audio") or {}).get("data")
            if data:
                pieces.append(base64.b64decode(data))
    return b"".join(pieces)


class AudioService:
    def __init__(self):
        self.api_key = os.getenv("OPENROUTER_API_KEY")
        self.model_id = MUSIC_MODEL
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://novelaine.com",
            "X-Title": "NovelAIne",
        }
        self.storage_bucket = os.getenv("BGM_STORAGE_BUCKET", "images")
        self.supabase = get_supabase_client()

    async def generate_scene_bgm(self, prompt: str, scene_id: str) -> Optional[str]:
        """Generate BGM, upload it to Supabase Storage, and return its public URL."""
        if not self.api_key:
            logger.warning("OPENROUTER_API_KEY is not configured. Skipping BGM generation.")
            return None

        # Audio output is only available as a stream.
        payload = {
            "model": self.model_id,
            "stream": True,
            "modalities": ["text", "audio"],
            "audio": {"format": "mp3"},
            "messages": [{"role": "user", "content": f"{INSTRUMENTAL} {prompt}"}],
        }

        try:
            async def request_bgm() -> bytes:
                async with httpx.AsyncClient() as client:
                    async with client.stream("POST", CHAT_API_URL, headers=self.headers, json=payload,
                                             timeout=180.0) as response:
                        if response.status_code != 200:
                            body = (await response.aread()).decode(errors="replace")
                            raise error_from_response("OpenRouter BGM", response.status_code, body)
                        return audio_from_stream([line async for line in response.aiter_lines()])

            audio_bytes = await with_timeout_retry("OpenRouter BGM", request_bgm)
            if not audio_bytes:
                logger.warning("BGM generation returned empty audio for scene %s", scene_id)
                return None

            filename = f"audio/bgm_{scene_id}_{os.urandom(4).hex()}.mp3"
            self.supabase.storage.from_(self.storage_bucket).upload(
                path=filename,
                file=audio_bytes,
                file_options={"content-type": "audio/mpeg"},
            )
            return self.supabase.storage.from_(self.storage_bucket).get_public_url(filename)

        except Exception as error:
            logger.error("BGM generation failed for scene %s: %s", scene_id, error)
            return None
