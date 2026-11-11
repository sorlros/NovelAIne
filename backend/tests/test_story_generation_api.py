import os
import unittest
from unittest.mock import patch

from fastapi import BackgroundTasks, HTTPException

from app.api import stories as stories_api
from app.llm_models import PRIMARY_FAST_LLM_MODEL, PRIMARY_PRO_LLM_MODEL
from app.services.story_generation import run_generation
from story_fakes import FakeClient, story_request

AUTH = "Bearer good-token"


class SkeletonCreateApiTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.client = FakeClient()
        patcher = patch.object(stories_api, "get_supabase_client", return_value=self.client)
        patcher.start()
        self.addCleanup(patcher.stop)

    async def create(self, **overrides):
        tasks = BackgroundTasks()
        with patch.dict(os.environ, {"SKELETON_MODE_ENABLED": "1"}):
            response = await stories_api.create_story(story_request(**overrides), tasks, authorization=AUTH)
        return response, tasks

    async def test_create_returns_at_once_and_queues_the_generation(self):
        response, tasks = await self.create()
        self.assertTrue(response.success)
        self.assertEqual(response.data["status"], "generating")
        self.assertEqual([(task.func, task.args) for task in tasks.tasks], [(run_generation, (response.data["id"],))])
        self.assertEqual(self.client.plan(response.data["id"])["status"], "queued")

    async def test_a_retried_create_returns_the_same_story(self):
        first, _ = await self.create()
        second, _ = await self.create()
        self.assertEqual(second.data["id"], first.data["id"])
        self.assertEqual(len(self.client.tables["stories"]), 1)

    async def test_a_third_concurrent_generation_is_refused(self):
        self.client.grant_premium("user-1")  # the free plan stops at one story a day before this limit
        await self.create(request_id="a")
        await self.create(request_id="b")
        with self.assertRaises(HTTPException) as caught:
            await self.create(request_id="c")
        self.assertEqual(caught.exception.status_code, 429)
        self.assertEqual(self.client.used("user-1", "story"), 2)  # the refused one gave its use back

    async def test_the_free_plan_makes_one_story_a_day(self):
        await self.create(request_id="a")
        with self.assertRaises(HTTPException) as caught:
            await self.create(request_id="b")
        self.assertEqual(caught.exception.status_code, 429)
        self.assertIn("1편", caught.exception.detail)
        self.assertEqual(len(self.client.tables["stories"]), 1)
        retried, _ = await self.create(request_id="a")  # a retry at the limit still gets its story
        self.assertEqual(retried.data["id"], self.client.tables["stories"][0]["id"])

    async def test_the_premium_engine_is_for_the_paid_plan(self):
        free, _ = await self.create(request_id="a", llm_model=PRIMARY_PRO_LLM_MODEL)
        self.assertEqual(free.data["llm_model"], PRIMARY_FAST_LLM_MODEL)
        self.client.grant_premium("user-1")
        paid, _ = await self.create(request_id="b", llm_model=PRIMARY_PRO_LLM_MODEL)
        self.assertEqual(paid.data["llm_model"], PRIMARY_PRO_LLM_MODEL)

    async def test_only_the_paid_plan_can_switch_a_story_to_the_premium_engine(self):
        created, _ = await self.create()
        with self.assertRaises(HTTPException) as caught:
            await stories_api.update_story(created.data["id"], {"llm_model": PRIMARY_PRO_LLM_MODEL}, authorization=AUTH)
        self.assertEqual(caught.exception.status_code, 403)
        self.client.grant_premium("user-1")
        updated = await stories_api.update_story(created.data["id"], {"llm_model": PRIMARY_PRO_LLM_MODEL},
                                                 authorization=AUTH)
        self.assertEqual(updated.data["llm_model"], PRIMARY_PRO_LLM_MODEL)

    async def test_a_skeleton_story_needs_a_signed_in_user(self):
        tasks = BackgroundTasks()
        with patch.dict(os.environ, {"SKELETON_MODE_ENABLED": "1"}):
            with self.assertRaises(HTTPException) as caught:
                await stories_api.create_story(story_request(user_id="11111111-1111-1111-1111-111111111111"), tasks,
                                               authorization=None)
        self.assertEqual(caught.exception.status_code, 401)
        self.assertEqual(self.client.tables.get("stories", []), [])

    async def test_a_client_cannot_change_status_progress_or_state(self):
        created, _ = await self.create()
        story_id = created.data["id"]
        for field, value in (("status", "active"), ("current_beat_seq", 9), ("world_state", {}), ("mode", "legacy")):
            with self.assertRaises(HTTPException, msg=field) as caught:
                await stories_api.update_story(story_id, {field: value}, authorization=AUTH)
            self.assertEqual(caught.exception.status_code, 400)
        self.assertEqual(self.client.story(story_id)["status"], "generating")  # the generation limit still holds
        response = await stories_api.update_story(story_id, {"title": "새 제목"}, authorization=AUTH)
        self.assertEqual(response.data["title"], "새 제목")

    async def test_generation_status_shows_progress_only(self):
        created, _ = await self.create()
        story_id = created.data["id"]
        self.client.plan(story_id).update({"world": {"secret": "ending"}, "lease_until": "2999-01-01T00:00:00+00:00"})
        tasks = BackgroundTasks()
        response = await stories_api.get_story_generation(story_id, tasks, authorization=AUTH)
        self.assertEqual(response.data, {"status": "queued", "step": "none", "error": None, "attempts": 0,
                                         "title": created.data["title"]})
        self.assertEqual(tasks.tasks, [])  # a live lease is left alone

    async def test_status_check_resumes_a_stalled_generation(self):
        created, _ = await self.create()
        tasks = BackgroundTasks()
        await stories_api.get_story_generation(created.data["id"], tasks, authorization=AUTH)
        self.assertEqual(len(tasks.tasks), 1)

    async def test_only_a_failed_generation_can_be_retried(self):
        created, _ = await self.create()
        story_id = created.data["id"]
        with self.assertRaises(HTTPException) as caught:
            await stories_api.retry_story_generation(story_id, BackgroundTasks(), authorization=AUTH)
        self.assertEqual(caught.exception.status_code, 409)
        self.client.plan(story_id).update({"status": "failed", "attempts": 3})
        tasks = BackgroundTasks()
        response = await stories_api.retry_story_generation(story_id, tasks, authorization=AUTH)
        self.assertEqual(response.data["status"], "queued")
        self.assertEqual(len(tasks.tasks), 1)

    async def test_listing_stories_resumes_stalled_generations(self):
        created, _ = await self.create()
        tasks = BackgroundTasks()
        await stories_api.list_stories(tasks, user_id=None, genre=None, status=None, limit=10, offset=0, authorization=AUTH)
        self.assertEqual([task.args for task in tasks.tasks], [(created.data["id"],)])

    async def test_the_legacy_path_is_used_when_the_flag_is_off(self):
        with patch.dict(os.environ, {"SKELETON_MODE_ENABLED": ""}), \
                patch.object(stories_api, "ChatService") as chat_service:
            chat_service.return_value.start_new_story.side_effect = RuntimeError("legacy path")
            with self.assertRaises(HTTPException) as caught:
                await stories_api.create_story(story_request(), BackgroundTasks(), authorization=AUTH)
        self.assertIn("legacy path", caught.exception.detail)
        self.assertNotIn("story_plans", self.client.tables)


if __name__ == "__main__":
    unittest.main()
