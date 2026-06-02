import os
from huggingface_hub import AsyncInferenceClient
from app.services.supabase_client import get_supabase_client
from typing import List, Optional
from uuid import UUID

class RagService:
    def __init__(self):
        # HuggingFace Inference API (Free Tier or Pro)
        # using 'sentence-transformers/all-MiniLM-L6-v2' which is standard for RAG
        self.api_key = os.getenv("HF_TOKEN")
        self.client = AsyncInferenceClient(token=self.api_key)
        self._supabase = None
        self.model_id = "sentence-transformers/all-MiniLM-L6-v2"

    @property
    def supabase(self):
        if self._supabase is None:
            self._supabase = get_supabase_client()
        return self._supabase

    async def generate_embedding(self, text: str) -> List[float]:
        """
        Generate embeddings using HuggingFace Feature Extraction API.
        """
        try:
            # feature_extraction returns a list of floats (embedding)
            embedding = await self.client.feature_extraction(text, model=self.model_id)
            # The API might return a list of lists or a single list depending on input
            # We assume single input, so we expect a 1D array (list of floats)
            # Ensure elements are native Python floats for JSON serialization
            return [float(x) for x in embedding]
        except Exception as e:
            print(f"Embedding generation failed: {e}")
            return []

    async def search_relevant_context(
        self,
        query: str,
        threshold: float = 0.4,
        limit: int = 3,
        story_id: Optional[UUID | str] = None,
        user_id: Optional[UUID | str] = None,
    ) -> str:
        """
        Search for relevant context in Supabase.
        """
        embedding = await self.generate_embedding(query)
        
        if not embedding:
            return ""

        try:
            rpc_args = {
                "query_embedding": embedding,
                "match_threshold": threshold,
                "match_count": limit,
            }
            if story_id:
                rpc_args["story_filter"] = str(story_id)
            if user_id:
                rpc_args["user_filter"] = str(user_id)

            try:
                response = self.supabase.rpc("search_similar_characters", rpc_args).execute()
            except Exception:
                legacy_args = {
                    "query_embedding": embedding,
                    "match_threshold": threshold,
                    "match_count": limit
                }
                response = self.supabase.rpc("search_similar_characters", legacy_args).execute()
            
            if not response.data:
                return ""

            context_text = "\n[관련 캐릭터 기억]\n"
            for item in response.data:
                context_text += f"- {item['name']}: {item['description']}\n"
            
            return context_text
            
        except Exception as e:
            print(f"RAG Search failed: {e}")
            return ""
