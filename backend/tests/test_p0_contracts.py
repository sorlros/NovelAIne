import asyncio
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import HTTPException

from app.api import auth as auth_api
from app.api import chat as chat_api
from app.api import media as media_api
from app.api import stories as stories_api
from app.services import auth_context
from app.services.external_errors import (
    ExternalServiceError,
    RATE_LIMIT_MESSAGE,
    TEMPORARY_MESSAGE,
    TIMEOUT_MESSAGE,
    error_from_exception,
    error_from_response,
)


class FakeResponse:
    def __init__(self, data=None):
        self.data = data


class FakeQuery:
    def __init__(self, client, table_name):
        self.client = client
        self.table_name = table_name
        self.filters = []
        self.exclusions = []
        self.operation = "select"
        self.payload = None
        self.single_result = False
        self.limit_count = None
        self.range_bounds = None
        self.order_field = None
        self.order_desc = False

    def select(self, *_args):
        self.operation = "select"
        return self

    def eq(self, field, value):
        self.filters.append((field, value))
        return self

    def neq(self, field, value):
        self.exclusions.append((field, value))
        return self

    def in_(self, field, values):
        self.filters.append((field, set(str(value) for value in values), "in"))
        return self

    def order(self, field, desc=False):
        self.order_field = field
        self.order_desc = desc
        return self

    def range(self, start, end):
        self.range_bounds = (start, end)
        return self

    def limit(self, count):
        self.limit_count = count
        return self

    def single(self):
        self.single_result = True
        return self

    def insert(self, payload):
        self.operation = "insert"
        self.payload = payload
        return self

    def update(self, payload):
        self.operation = "update"
        self.payload = payload
        return self

    def delete(self):
        self.operation = "delete"
        return self

    def upsert(self, payload):
        self.operation = "upsert"
        self.payload = payload
        return self

    def execute(self):
        rows = self.client.tables.setdefault(self.table_name, [])
        if self.operation in {"insert", "upsert"}:
            payloads = self.payload if isinstance(self.payload, list) else [self.payload]
            inserted = []
            for payload in payloads:
                row = dict(payload)
                row.setdefault("id", f"{self.table_name}-{len(rows) + 1}")
                rows.append(row)
                inserted.append(row)
            return FakeResponse(inserted)

        matched = [row for row in rows if self._matches(row)]
        if self.operation == "update":
            for row in matched:
                row.update(self.payload)
            return FakeResponse(matched)
        if self.operation == "delete":
            self.client.tables[self.table_name] = [row for row in rows if not self._matches(row)]
            return FakeResponse(matched)

        if self.order_field is not None:
            matched.sort(key=lambda row: row.get(self.order_field) or 0, reverse=self.order_desc)
        if self.limit_count is not None:
            matched = matched[: self.limit_count]
        if self.range_bounds is not None:
            start, end = self.range_bounds
            matched = matched[start : end + 1]
        if self.single_result:
            return FakeResponse(matched[0] if matched else None)
        return FakeResponse(matched)

    def _matches(self, row):
        for item in self.filters:
            if len(item) == 3 and item[2] == "in":
                if str(row.get(item[0])) not in item[1]:
                    return False
                continue
            field, value = item
            if str(row.get(field)) != str(value):
                return False
        return all(str(row.get(field)) != str(value) for field, value in self.exclusions)


class FakeAuth:
    def __init__(self, user_id="user-1"):
        self.user_id = user_id

    def get_user(self, token):
        if token == "bad-token":
            raise ValueError("invalid token")
        return SimpleNamespace(user=SimpleNamespace(id=self.user_id))


class FakeClient:
    def __init__(self, user_id="user-1"):
        self.auth = FakeAuth(user_id)
        self.tables = {
            "stories": [
                {
                    "id": "11111111-1111-4111-8111-111111111111",
                    "user_id": "user-1",
                    "visibility": "private",
                    "status": "active",
                },
                {
                    "id": "22222222-2222-4222-8222-222222222222",
                    "user_id": "user-2",
                    "visibility": "public",
                    "status": "active",
                    "published_at": "2026-06-01T00:00:00Z",
                    "users": {"username": "Public Writer", "avatar_url": None},
                },
            ],
            "scenes": [],
            "media_jobs": [],
        }

    def table(self, table_name):
        return FakeQuery(self, table_name)


class ExternalErrorContractTest(unittest.TestCase):
    def test_external_error_user_messages_are_standardised(self):
        self.assertEqual(error_from_response("OpenRouter", 429, "busy").user_message, RATE_LIMIT_MESSAGE)
        self.assertEqual(error_from_response("HuggingFace", 502, "bad").user_message, TEMPORARY_MESSAGE)
        self.assertEqual(error_from_exception("OpenRouter", TimeoutError("slow")).user_message, TIMEOUT_MESSAGE)

    def test_media_job_error_is_user_safe(self):
        self.assertEqual(media_api._safe_job_error(RuntimeError("Image generation failed")), TEMPORARY_MESSAGE)


class AuthAndAccessContractTest(unittest.TestCase):
    def test_auth_refresh_error_is_user_friendly(self):
        self.assertIn("세션", auth_api._friendly_auth_error(Exception("Invalid Refresh Token")))

    def test_story_owner_access_and_public_read_contract(self):
        client = FakeClient(user_id="user-1")
        owner_id = auth_context.ensure_story_access(client, "11111111-1111-4111-8111-111111111111", "Bearer good-token")
        self.assertEqual(owner_id, "user-1")

        public_viewer = auth_context.ensure_story_read_access(client, "22222222-2222-4222-8222-222222222222", None)
        self.assertIsNone(public_viewer)

        with self.assertRaises(HTTPException) as context:
            auth_context.ensure_story_access(FakeClient(user_id="user-2"), "11111111-1111-4111-8111-111111111111", "Bearer good-token")
        self.assertEqual(context.exception.status_code, 403)


class StoriesAndMediaContractTest(unittest.IsolatedAsyncioTestCase):
    async def test_public_stories_contract_returns_only_public_rows(self):
        client = FakeClient()
        with patch.object(stories_api, "get_supabase_client", return_value=client):
            response = await stories_api.list_public_stories(limit=20, offset=0)

        self.assertTrue(response.success)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["visibility"], "public")
        self.assertEqual(response.data[0]["author"]["username"], "Public Writer")

    async def test_media_job_contract_reuses_existing_scene_media(self):
        from fastapi import BackgroundTasks

        client = FakeClient()
        client.tables["scenes"] = [
            {
                "id": "33333333-3333-4333-8333-333333333333",
                "story_id": "11111111-1111-4111-8111-111111111111",
                "content": "moonlit gate",
                "image_url": "https://example.com/image.png",
            }
        ]
        request = media_api.MediaJobCreate(
            story_id="11111111-1111-4111-8111-111111111111",
            scene_id="33333333-3333-4333-8333-333333333333",
            media_type="image",
        )
        with patch.object(media_api, "get_supabase_client", return_value=client), patch.object(
            media_api, "ensure_story_access", return_value="user-1"
        ):
            response = await media_api.create_media_job(
                request,
                BackgroundTasks(),
                authorization="Bearer good-token",
            )

        self.assertTrue(response.success)
        self.assertEqual(response.data["job"]["status"], "succeeded")
        self.assertEqual(response.data["job"]["result_url"], "https://example.com/image.png")


class ChatStreamContractTest(unittest.IsolatedAsyncioTestCase):
    async def test_stream_reuses_existing_client_request_without_llm_call(self):
        client = FakeClient()
        client.tables["scenes"] = [
            {
                "id": "scene-user",
                "story_id": "11111111-1111-4111-8111-111111111111",
                "role": "user",
                "sequence": 1,
                "client_request_id": "request-1",
                "content": "open",
            },
            {
                "id": "scene-ai",
                "story_id": "11111111-1111-4111-8111-111111111111",
                "role": "ai",
                "sequence": 2,
                "client_request_id": "request-1",
                "content": "opened",
            },
        ]

        request = chat_api.ChatRequest(
            story_id="11111111-1111-4111-8111-111111111111",
            message="open",
            client_request_id="request-1",
        )
        with patch.object(chat_api, "get_supabase_client", return_value=client), patch.object(
            chat_api, "ensure_story_access", return_value="user-1"
        ), patch.object(chat_api, "_get_story_metadata", return_value={}):
            response = await chat_api.chat_stream(request, authorization="Bearer good-token")

        chunks = []
        async for chunk in response.body_iterator:
            chunks.append(chunk.decode() if isinstance(chunk, bytes) else chunk)
        self.assertEqual("".join(chunks), "opened")

    async def test_stream_error_returns_recoverable_marker_without_persisting(self):
        class FailingChatService:
            async def stream_generate_response(self, *_args, **_kwargs):
                raise ExternalServiceError(
                    "OpenRouter streaming",
                    TIMEOUT_MESSAGE,
                    "timeout",
                    retryable=True,
                )
                yield ""

        client = FakeClient()
        request = chat_api.ChatRequest(
            story_id="11111111-1111-4111-8111-111111111111",
            message="open",
            client_request_id="request-2",
        )
        with patch.object(chat_api, "get_supabase_client", return_value=client), patch.object(
            chat_api, "ensure_story_access", return_value="user-1"
        ), patch.object(chat_api, "_get_story_metadata", return_value={}), patch.object(
            chat_api, "ChatService", return_value=FailingChatService()
        ):
            response = await chat_api.chat_stream(request, authorization="Bearer good-token")

        chunks = []
        async for chunk in response.body_iterator:
            chunks.append(chunk.decode() if isinstance(chunk, bytes) else chunk)
        self.assertIn("[STREAM_ERROR:", "".join(chunks))
        self.assertEqual(client.tables["scenes"], [])


if __name__ == "__main__":
    unittest.main()
