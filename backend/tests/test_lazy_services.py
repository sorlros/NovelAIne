import unittest
from unittest.mock import patch

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
