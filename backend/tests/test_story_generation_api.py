import os
import unittest
from unittest.mock import patch

from fastapi import BackgroundTasks, HTTPException

from app.api import stories as stories_api
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
        await self.create(request_id="a")
        await self.create(request_id="b")
        with self.assertRaises(HTTPException) as caught:
            await self.create(request_id="c")
        self.assertEqual(caught.exception.status_code, 429)

    async def test_generation_status_shows_progress_only(self):
        created, _ = await self.create()
        story_id = created.data["id"]
        self.client.plan(story_id).update({"world": {"secret": "ending"}, "lease_until": "2999-01-01T00:00:00+00:00"})
        tasks = BackgroundTasks()
        response = await stories_api.get_story_generation(story_id, tasks, authorization=AUTH)
        self.assertEqual(response.data, {"status": "queued", "step": "none", "error": None, "attempts": 0})
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
