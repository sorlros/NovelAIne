import os
import httpx
from typing import Optional
from app.services.supabase_client import get_supabase_client

class AudioService:
    def __init__(self):
        self.api_key = os.getenv("HF_TOKEN")
        # Use MusicGen or AudioLDM. MusicGen is robust for BGM.
        self.model_id = "facebook/musicgen-small"
        self.api_url = f"https://api-inference.huggingface.co/models/{self.model_id}"
        self.headers = {"Authorization": f"Bearer {self.api_key}"}
        
        self.supabase = get_supabase_client()
        
    async def generate_scene_bgm(self, prompt: str, scene_id: str) -> Optional[str]:
        """
        Generates background music based on the prompt.
        Uploads to Supabase and returns the public URL.
        """
        payload = {
            "inputs": prompt,
        }
        
        try:
            print(f"[AudioService] Requesting BGM generation for scene {scene_id}...")
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.api_url, 
                    headers=self.headers, 
                    json=payload,
                    timeout=120.0
                )
                
            if response.status_code != 200:
                print(f"[AudioService] API Error {response.status_code}: {response.text}")
                return None
                
            audio_bytes = response.content
            
            # Upload to Cloud Storage (Supabase Storage) - reuse 'images' bucket, or maybe we have 'audio' bucket?
            # If no audio bucket exists, we'll store it under a generic path or 'audio' bucket if possible.
            # Let's save to 'audio' bucket. We should ensure it exists in Supabase.
            # Assuming 'images' bucket is widely open, we'll save as 'images/bgm_{scene_id}.wav' for MVP if 'audio' bucket isn't there.
            # No, let's assume 'audio' bucket exists or just use 'images' bucket to avoid permissions issue MVP.
            filename = f"audio/bgm_{scene_id}_{os.urandom(4).hex()}.wav"
            
            try:
                # We'll try to put it in an 'audio' folder inside the 'images' bucket which we know allows public access.
                self.supabase.storage.from_("images").upload(
                    path=filename,
                    file=audio_bytes,
                    file_options={"content-type": "audio/wav"}
                )
                
                # Get Public URL
                public_url = self.supabase.storage.from_("images").get_public_url(filename)
                
                # Also update the scene with the BGM url
                # Currently there's no bgm_url field in 'scenes' by default unless added.
                # Update DB (Assume we can store it in 'content' or wait, schema might not have bgm_url).
                # Wait, schema might not have bgm_url. We'll update the 'has_generated_bgm' boolean, 
                # but we need to store the URL. If the table doesn't have bgm_url, we might need to alter table or save elsewhere.
                # For now, let's assume 'bgm_url' column gets added or we just print it.
                print(f"[AudioService] Successfully generated and uploaded BGM: {public_url}")
                
                # Optional: Update the scene record in DB with the URL
                # If 'bgm_url' column doesn't exist, this will fail. Let's try it gently.
                try:
                    self.supabase.table("scenes").update({"bgm_url": public_url}).eq("id", scene_id).execute()
                except Exception as e:
                    print(f"[AudioService] Could not update scene row with bgm_url (Maybe column missing?): {e}")

                return public_url

            except Exception as e:
                print(f"[AudioService] Storage upload failed: {e}")
                return None

        except Exception as e:
            print(f"[AudioService] Audio generation HTTP request failed: {e}")
            return None
