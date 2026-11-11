import base64
import logging
import os
from typing import Optional, Tuple

import httpx

from app.services.external_errors import error_from_response, with_timeout_retry
from app.services.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)

IMAGE_MODEL = "openai/gpt-image-2"  # anime-style novel illustrations; about $0.03 an image (2026-11)
IMAGE_API_URL = "https://openrouter.ai/api/v1/images"
IMAGE_STYLE = "애니메이션 스타일의 소설 삽화. 그림 안에 글자나 문자는 넣지 않는다."
EXTENSIONS = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}


def image_from_response(body: dict) -> Tuple[bytes, str]:
    """The first image of an OpenRouter image response, with its media type."""
    item = (body.get("data") or [{}])[0]
    data = item.get("b64_json") or ""
    if not data:
        raise ValueError("The image response has no image")
    return base64.b64decode(data.split(",")[-1]), item.get("media_type") or "image/png"


class ImageService:
    def __init__(self):
        self.api_key = os.getenv("OPENROUTER_API_KEY")
        self.model_id = IMAGE_MODEL
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://novelaine.com",
            "X-Title": "NovelAIne",
        }
        self._supabase = None

    @property
    def supabase(self):
        if self._supabase is None:
            self._supabase = get_supabase_client()
        return self._supabase

    async def generate_anime_image(self, prompt: str, scene_type: str, message_id: str, character_appearance: Optional[str] = None) -> Optional[str]:
        """
        Generates an anime-style image depending on the scene_type ('dialogue'=1:1, 'event'=16:9).
        Uploads to Supabase and returns the public URL.
        """
        if not self.api_key:
            logger.warning("OPENROUTER_API_KEY is not configured. Skipping image generation.")
            return None

        appearance = f" 주인공의 외모: {character_appearance}." if character_appearance else ""
        payload = {
            "model": self.model_id,
            "prompt": f"{IMAGE_STYLE} {prompt}{appearance}",
            "aspect_ratio": "16:9" if scene_type == "event" else "1:1",
            "output_format": "jpeg",
        }

        try:
            logger.info("Requesting image generation for %s", scene_type)

            async def request_image() -> httpx.Response:
                async with httpx.AsyncClient() as client:
                    response = await client.post(IMAGE_API_URL, headers=self.headers, json=payload, timeout=180.0)
                if response.status_code != 200:
                    raise error_from_response("OpenRouter image", response.status_code, response.text)
                return response

            response = await with_timeout_retry("OpenRouter image", request_image)
            image_bytes, media_type = image_from_response(response.json())

            filename = f"images/{message_id}_{os.urandom(4).hex()}.{EXTENSIONS.get(media_type, 'png')}"
            try:
                self.supabase.storage.from_("images").upload(
                    path=filename,
                    file=image_bytes,
                    file_options={"content-type": media_type},
                )
                public_url = self.supabase.storage.from_("images").get_public_url(filename)
                logger.info("Successfully generated and uploaded image: %s", public_url)
                return public_url
            except Exception as e:
                logger.error("Supabase Storage image upload failed: %s", e)
                return None

        except Exception as e:
            logger.error("Image generation failed: %s", e)
            return None
