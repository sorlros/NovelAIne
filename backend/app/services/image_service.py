import os
import io
import httpx
from app.services.supabase_client import get_supabase_client
from typing import Optional

class ImageService:
    def __init__(self):
        self.api_key = os.getenv("HF_TOKEN")
        # Use Animagine XL 3.1 for anime style illustration
        self.model_id = "cagliostrolab/animagine-xl-3.1"
        self.api_url = f"https://router.huggingface.co/hf-inference/models/{self.model_id}"
        self.headers = {"Authorization": f"Bearer {self.api_key}"}
        
        self.supabase = get_supabase_client()
        
    async def generate_anime_image(self, prompt: str, scene_type: str, message_id: str, character_appearance: Optional[str] = None) -> Optional[str]:
        """
        Generates an anime-style image depending on the scene_type ('dialogue'=1:1, 'event'=16:9).
        Uploads to Supabase and returns the public URL.
        """
        # Define dimensions
        width = 832
        height = 832
        
        if scene_type == 'event':
            width = 1024
            height = 576  # 16:9ish
            
        # Refine prompt for anime quality
        quality_tags = "masterpiece, best quality, very aesthetic, absurdres"
        negative_prompt = "lowres, (bad), text, error, missing fingers, extra digit, fewer digits, cropped, worst quality, low quality, jpeg artifacts, signature, watermark, username, blurry"
        
        char_tags = ""
        if character_appearance:
            char_tags = f"1boy/1girl, {character_appearance}, "
            
        full_prompt = f"{char_tags}{prompt}, {quality_tags}"
        
        payload = {
            "inputs": full_prompt,
            "parameters": {
                "negative_prompt": negative_prompt,
                "width": width,
                "height": height,
                "num_inference_steps": 25,
                "guidance_scale": 7.0
            }
        }
        
        try:
            print(f"[ImageService] Requesting generation for {scene_type} ({width}x{height})...")
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.api_url, 
                    headers=self.headers, 
                    json=payload,
                    timeout=120.0
                )
                
            if response.status_code != 200:
                print(f"[ImageService] API Error {response.status_code}: {response.text}")
                return None
                
            image_bytes = response.content
            
            # 3. Upload to Cloud Storage (Supabase Storage)
            filename = f"images/{message_id}_{os.urandom(4).hex()}.png"
            
            try:
                self.supabase.storage.from_("images").upload(
                    path=filename,
                    file=image_bytes,
                    file_options={"content-type": "image/png"}
                )
                
                # Get Public URL
                public_url = self.supabase.storage.from_("images").get_public_url(filename)
                print(f"[ImageService] Successfully generated and uploaded image: {public_url}")
                return public_url

            except Exception as e:
                print(f"[ImageService] Storage upload failed: {e}")
                return None

        except Exception as e:
            print(f"[ImageService] Image generation HTTP request failed: {e}")
            return None
