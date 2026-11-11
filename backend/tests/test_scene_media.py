import base64
import json
import unittest
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from app.api import media as media_api
from app.api import story_play as play_api
from app.services.audio_service import audio_from_stream
from app.services.image_service import image_from_response
from app.services.story_play import wants_media
from story_fakes import FakeClient


PROMPTS = {"image": "그림", "bgm": "음악"}


def turn_at(intensity=None):
    """A turn whose scene is a major event of this intensity, or a scene between major events."""
    return SimpleNamespace(spine_event=None if intensity is None else {"id": "e04", "intensity": intensity})


class WantsMediaTest(unittest.TestCase):
    def test_only_tense_major_events_get_a_picture_and_music(self):
        self.assertTrue(wants_media(turn_at(4)))
        self.assertTrue(wants_media(turn_at(5)))
        self.assertFalse(wants_media(turn_at(3)))
        self.assertFalse(wants_media(turn_at(None)))  # a scene between major events
        self.assertFalse(wants_media(SimpleNamespace(spine_event={"id": "e04"})))  # no intensity


class AfterTurnTest(unittest.IsolatedAsyncioTestCase):
    async def test_the_media_queued_with_the_turn_is_made_after_the_response(self):
        with patch.object(play_api, "needs_next_segment", return_value=False), \
                patch.object(play_api, "run_media_jobs", new=AsyncMock()) as run:
            await play_api.after_turn("story-1", turn_at(5), {"media_jobs": ["job-1", "job-2"]})
            await play_api.after_turn("story-1", turn_at(2), {})
        self.assertEqual([call.args for call in run.await_args_list], [(["job-1", "job-2"],), ([],)])


class SceneMediaTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.client = FakeClient()
        self.client.tables["scenes"] = [{"id": "scene-9", "story_id": "story-1", "content": "성벽이 무너졌다."}]
        patcher = patch.object(media_api, "get_supabase_client", return_value=self.client)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_a_turning_point_queues_a_picture_and_music(self):
        ids = media_api.queue_scene_media(self.client, "story-1", "scene-9", "user-1", PROMPTS)
        jobs = self.client.rows("media_jobs")
        self.assertEqual(ids, [job["id"] for job in jobs])
        self.assertEqual([(job["media_type"], job["status"], job["scene_id"], job["prompt"]) for job in jobs],
                         [("image", "queued", "scene-9", "그림"), ("bgm", "queued", "scene-9", "음악")])

    def test_a_missing_scene_queues_nothing(self):
        self.assertEqual(media_api.queue_scene_media(self.client, "story-1", "gone", "user-1", PROMPTS), [])
        self.assertEqual(self.client.rows("media_jobs"), [])

    async def test_queued_jobs_run_one_after_another(self):
        with patch.object(media_api, "_run_media_job", new=AsyncMock()) as run:
            await media_api.run_media_jobs(["job-1", "job-2"])
        self.assertEqual([call.args for call in run.await_args_list], [("job-1",), ("job-2",)])

    def test_pending_counts_only_recent_active_jobs(self):
        now = datetime.now(timezone.utc)

        def job(status, minutes_ago):
            return {"story_id": "story-1", "status": status,
                    "created_at": (now - timedelta(minutes=minutes_ago)).isoformat()}

        self.client.tables["media_jobs"] = [job("succeeded", 1), job("failed", 1), job("running", 30)]
        self.assertFalse(media_api.media_pending(self.client, "story-1"))  # the old one was lost with a restart
        self.client.tables["media_jobs"].append(job("queued", 1))
        self.assertTrue(media_api.media_pending(self.client, "story-1"))
        self.assertFalse(media_api.media_pending(self.client, "story-2"))


class OpenRouterResponseTest(unittest.TestCase):
    """The response shapes seen from OpenRouter on 2026-11-11."""

    def test_the_image_comes_as_base64_with_its_media_type(self):
        body = {"created": 1, "data": [{"b64_json": base64.b64encode(b"jpeg-bytes").decode(), "media_type": "image/jpeg"}]}
        self.assertEqual(image_from_response(body), (b"jpeg-bytes", "image/jpeg"))
        with self.assertRaises(ValueError):
            image_from_response({"data": []})

    def test_the_music_comes_as_base64_pieces_in_the_stream(self):
        def line(delta):
            return "data: " + json.dumps({"choices": [{"delta": delta}]})

        lines = [": OPENROUTER PROCESSING", line({"role": "assistant", "content": "<instrumental>"}),
                 line({"audio": {"data": base64.b64encode(b"ID3").decode()}}),
                 line({"audio": {"data": base64.b64encode(b"-rest").decode()}}), "data: [DONE]"]
        self.assertEqual(audio_from_stream(lines), b"ID3-rest")


if __name__ == "__main__":
    unittest.main()
