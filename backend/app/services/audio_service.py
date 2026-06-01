import os
import logging
import httpx
from typing import Optional
from app.services.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)


class AudioService:
    def __init__(self):
        self.api_key = os.getenv("HF_TOKEN")
        self.model_id = "facebook/musicgen-small"
        self.api_url = f"https://router.huggingface.co/hf-inference/models/{self.model_id}"
        self.headers = {"Authorization": f"Bearer {self.api_key}"}
        self.storage_bucket = os.getenv("BGM_STORAGE_BUCKET", "images")
        self.supabase = get_supabase_client()

    async def generate_scene_bgm(self, prompt: str, scene_id: str) -> Optional[str]:
        """Generate BGM, upload it to Supabase Storage, and return its public URL."""
        if not self.api_key:
            logger.warning("HF_TOKEN is not configured. Skipping BGM generation.")
            return None

        payload = {"inputs": prompt}

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.api_url,
                    headers=self.headers,
                    json=payload,
                    timeout=120.0,
                )

            if response.status_code != 200:
                logger.warning(
                    "BGM generation failed for scene %s: %s %s",
                    scene_id,
                    response.status_code,
                    response.text[:500],
                )
                return None

            audio_bytes = response.content
            if not audio_bytes:
                logger.warning("BGM generation returned empty audio for scene %s", scene_id)
                return None

            filename = f"audio/bgm_{scene_id}_{os.urandom(4).hex()}.wav"
            self.supabase.storage.from_(self.storage_bucket).upload(
                path=filename,
                file=audio_bytes,
                file_options={"content-type": "audio/wav"},
            )
            return self.supabase.storage.from_(self.storage_bucket).get_public_url(filename)

        except Exception as error:
            logger.error("BGM generation failed for scene %s: %s", scene_id, error)
            return None
