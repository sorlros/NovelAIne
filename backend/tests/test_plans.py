import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

from fastapi import BackgroundTasks, HTTPException

from app.api import audio as audio_api
from app.api import images as images_api
from app.api import media as media_api
from app.api import plans as plans_api
from app.llm_models import PRIMARY_FAST_LLM_MODEL, PRIMARY_PRO_LLM_MODEL
from app.services import plans
from story_fakes import FakeClient

AUTH = "Bearer good-token"


class PlanTest(unittest.TestCase):
    def setUp(self):
        self.client = FakeClient()

    def test_everyone_is_free_until_given_the_paid_plan(self):
        self.assertEqual(plans.user_plan(self.client, "user-1"), plans.FREE)
        self.client.grant_premium("user-1")
        self.assertEqual(plans.user_plan(self.client, "user-1"), plans.PREMIUM)
        self.assertEqual(plans.user_plan(self.client, "user-2"), plans.FREE)

    def test_an_expired_paid_plan_is_free(self):
        past = (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()
        future = (datetime.now(timezone.utc) + timedelta(days=1)).isoformat().replace("+00:00", "Z")
        self.client.grant_premium("user-1", expires_at=past)
        self.client.grant_premium("user-2", expires_at=future)
        self.assertEqual(plans.user_plan(self.client, "user-1"), plans.FREE)
        self.assertEqual(plans.user_plan(self.client, "user-2"), plans.PREMIUM)

    def test_the_premium_engine_falls_back_to_the_standard_one_on_the_free_plan(self):
        self.assertEqual(plans.engine_for(plans.FREE, PRIMARY_PRO_LLM_MODEL), PRIMARY_FAST_LLM_MODEL)
        self.assertEqual(plans.engine_for(plans.PREMIUM, PRIMARY_PRO_LLM_MODEL), PRIMARY_PRO_LLM_MODEL)
        self.assertEqual(plans.engine_for(plans.FREE, PRIMARY_FAST_LLM_MODEL), PRIMARY_FAST_LLM_MODEL)
        self.assertIsNone(plans.engine_for(plans.FREE, None))

    def test_daily_uses_stop_at_the_plan_limit_and_can_be_given_back(self):
        self.assertEqual(plans.use_daily(self.client, "user-1", plans.STORY, plans.FREE), (True, 1))
        self.assertEqual(plans.use_daily(self.client, "user-1", plans.STORY, plans.FREE), (False, 1))
        plans.give_back_daily(self.client, "user-1", plans.STORY)
        self.assertTrue(plans.use_daily(self.client, "user-1", plans.STORY, plans.FREE)[0])
        self.assertTrue(plans.use_daily(self.client, "user-1", plans.STORY, plans.PREMIUM)[0])  # paid: 10

    def test_the_summary_shows_the_limits_and_todays_uses(self):
        today = datetime.now(timezone.utc).astimezone(plans.KST).date().isoformat()
        self.client.tables["daily_usage"] = [{"user_id": "user-1", "day": today, "kind": "turn", "count": 7},
                                             {"user_id": "user-1", "day": "2000-01-01", "kind": "story", "count": 1}]
        summary = plans.plan_summary(self.client, "user-1")
        self.assertEqual(summary, {"plan": "free", "premium": False,
                                   "limits": {"story": 1, "turn": 30, "direct_input": 10},
                                   "used": {"story": 0, "turn": 7, "direct_input": 0}})


class PaidMediaTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.client = FakeClient()
        self.client.tables["stories"] = [{"id": "11111111-1111-4111-8111-111111111111", "user_id": "user-1"}]
        self.client.tables["scenes"] = [{"id": "33333333-3333-4333-8333-333333333333",
                                         "story_id": "11111111-1111-4111-8111-111111111111", "content": "성문"}]
        for module in (media_api, audio_api, images_api, plans_api):
            patcher = patch.object(module, "get_supabase_client", return_value=self.client)
            patcher.start()
            self.addCleanup(patcher.stop)

    async def test_the_free_plan_cannot_make_pictures_or_music(self):
        story, scene = self.client.tables["stories"][0]["id"], self.client.tables["scenes"][0]["id"]
        calls = [
            media_api.create_media_job(media_api.MediaJobCreate(story_id=story, scene_id=scene, media_type="bgm"),
                                       BackgroundTasks(), authorization=AUTH),
            audio_api.generate_scene_bgm(audio_api.BgmGenerateRequest(story_id=story, scene_id=scene),
                                         authorization=AUTH),
            images_api.generate_image(images_api.ImageGenerateRequest(message_id="m", prompt="p", scene_type="event"),
                                      authorization=AUTH),
        ]
        for call in calls:
            with self.assertRaises(HTTPException) as caught:
                await call
            self.assertEqual(caught.exception.status_code, 403)
        self.assertEqual(self.client.tables.get("media_jobs", []), [])

    async def test_pictures_need_a_signed_in_user_even_without_a_story(self):
        with self.assertRaises(HTTPException) as caught:
            await images_api.generate_image(images_api.ImageGenerateRequest(message_id="m", prompt="p",
                                                                            scene_type="event"), authorization=None)
        self.assertEqual(caught.exception.status_code, 401)

    async def test_the_paid_plan_can_queue_music(self):
        self.client.grant_premium("user-1")
        story, scene = self.client.tables["stories"][0]["id"], self.client.tables["scenes"][0]["id"]
        response = await media_api.create_media_job(
            media_api.MediaJobCreate(story_id=story, scene_id=scene, media_type="bgm"), BackgroundTasks(),
            authorization=AUTH)
        self.assertEqual(response.data["job"]["status"], "queued")

    async def test_the_app_reads_the_plan(self):
        response = await plans_api.get_my_plan(authorization=AUTH)
        self.assertEqual((response.data["plan"], response.data["limits"]["turn"]), ("free", 30))
        with self.assertRaises(HTTPException) as caught:
            await plans_api.get_my_plan(authorization=None)
        self.assertEqual(caught.exception.status_code, 401)


if __name__ == "__main__":
    unittest.main()
