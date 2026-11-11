import unittest
from unittest.mock import patch

from app.llm_models import (
    FAST_FALLBACK_LLM_MODEL,
    PRIMARY_FAST_LLM_MODEL,
    PRIMARY_PRO_LLM_MODEL,
    PRO_FALLBACK_LLM_MODEL,
    normalize_llm_model,
)
from app.api import images as images_api
from app.services.chat_service import ChatService
from app.services.image_service import ImageService
from app.services.rag_service import RagService


class LazyServiceInitialisationTest(unittest.TestCase):
    def test_image_service_does_not_create_supabase_client_on_initialisation(self):
        with patch(
            "app.services.image_service.get_supabase_client",
            side_effect=AssertionError("Supabase client should be lazy"),
        ):
            ImageService()

    def test_image_service_reuses_lazy_supabase_client(self):
        service = ImageService()
        sentinel = object()

        with patch(
            "app.services.image_service.get_supabase_client",
            return_value=sentinel,
        ) as get_supabase_client:
            self.assertIs(service.supabase, sentinel)
            self.assertIs(service.supabase, sentinel)

        get_supabase_client.assert_called_once()

    def test_rag_service_does_not_create_supabase_client_on_initialisation(self):
        with patch(
            "app.services.rag_service.get_supabase_client",
            side_effect=AssertionError("Supabase client should be lazy"),
        ):
            RagService()

    def test_rag_service_reuses_lazy_supabase_client(self):
        service = RagService()
        sentinel = object()

        with patch(
            "app.services.rag_service.get_supabase_client",
            return_value=sentinel,
        ) as get_supabase_client:
            self.assertIs(service.supabase, sentinel)
            self.assertIs(service.supabase, sentinel)

        get_supabase_client.assert_called_once()

    def test_chat_service_does_not_create_rag_service_on_initialisation(self):
        with patch(
            "app.services.chat_service.RagService",
            side_effect=AssertionError("RAG service should be lazy"),
        ):
            ChatService()

    def test_chat_service_reuses_lazy_rag_service(self):
        service = ChatService()
        sentinel = object()

        with patch(
            "app.services.chat_service.RagService",
            return_value=sentinel,
        ) as rag_service:
            self.assertIs(service.rag_service, sentinel)
            self.assertIs(service.rag_service, sentinel)

        rag_service.assert_called_once()

    def test_chat_service_model_candidates_use_the_primary_engines_and_their_fallbacks(self):
        service = ChatService()

        self.assertEqual(
            service._candidate_models(PRIMARY_FAST_LLM_MODEL),
            [PRIMARY_FAST_LLM_MODEL, FAST_FALLBACK_LLM_MODEL],
        )
        self.assertEqual(
            service._candidate_models(PRIMARY_PRO_LLM_MODEL),
            [PRIMARY_PRO_LLM_MODEL, PRO_FALLBACK_LLM_MODEL],
        )
        self.assertEqual(
            service._candidate_models("google/gemini-2.0-flash-001"),
            [PRIMARY_FAST_LLM_MODEL, FAST_FALLBACK_LLM_MODEL],
        )
        self.assertEqual(
            normalize_llm_model("google/gemini-pro-1.5"),
            PRIMARY_PRO_LLM_MODEL,
        )

    def test_stories_saved_with_the_previous_engines_move_to_the_current_ones(self):
        service = ChatService()
        self.assertEqual(service._candidate_models("google/gemini-3.1-flash-lite"),
                         ["deepseek/deepseek-v4.1-flash", "google/gemini-3.1-flash-lite"])
        self.assertEqual(service._candidate_models("google/gemini-3.1-pro-preview"),
                         ["anthropic/claude-sonnet-5.5", "google/gemini-3.1-pro-preview"])

    def test_sonnet_gets_room_for_its_reasoning(self):
        from app.llm_models import request_for

        body = request_for({"max_tokens": 4000, "messages": []}, PRIMARY_PRO_LLM_MODEL)
        self.assertEqual(body["max_tokens"], 24000)
        self.assertNotIn("reasoning", body)  # it cannot be turned off, and lowering it hurt the plans
        self.assertEqual(request_for({"max_tokens": 30000}, PRIMARY_PRO_LLM_MODEL)["max_tokens"], 30000)
        self.assertEqual(request_for({"max_tokens": 4000}, PRIMARY_FAST_LLM_MODEL)["max_tokens"], 4000)

    def test_deepseek_is_asked_not_to_reason_and_its_fallback_is_not(self):
        import asyncio
        from types import SimpleNamespace

        sent = []

        class Client:
            async def __aenter__(self):
                return self

            async def __aexit__(self, *_):
                return False

            async def post(self, url, headers=None, json=None, timeout=None):
                sent.append(json)
                status = 503 if len(sent) == 1 else 200  # the primary fails, the fallback answers
                return SimpleNamespace(status_code=status, text="unavailable", json=lambda: {})

        service = ChatService()
        with patch("app.services.chat_service.httpx.AsyncClient", Client), \
                patch("app.services.chat_service.with_timeout_retry", lambda _name, operation: operation()):
            asyncio.run(service._post_openrouter({"model": PRIMARY_FAST_LLM_MODEL, "messages": []}, 5))
        self.assertEqual([body["model"] for body in sent], [PRIMARY_FAST_LLM_MODEL, FAST_FALLBACK_LLM_MODEL])
        self.assertEqual(sent[0]["reasoning"], {"enabled": False})
        self.assertNotIn("reasoning", sent[1])

    def test_images_api_reuses_lazy_image_service(self):
        sentinel = object()
        images_api._image_service = None
        try:
            with patch.object(
                images_api,
                "ImageService",
                return_value=sentinel,
            ) as image_service:
                self.assertIs(images_api.get_image_service(), sentinel)
                self.assertIs(images_api.get_image_service(), sentinel)

            image_service.assert_called_once()
        finally:
            images_api._image_service = None


if __name__ == "__main__":
    unittest.main()
