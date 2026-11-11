import unittest
from unittest.mock import patch

from fastapi import BackgroundTasks, HTTPException
from pydantic import ValidationError

from app.api import chat as chat_api
from app.api import scenes as scenes_api
from app.api import story_play as play_api
from app.schemas.models import SceneCreate
from app.services.external_errors import ExternalServiceError
from app.services.story_play import available_choices, load_context, plan_next_segment
from story_fakes import FakeModel
from test_story_play import planner_for, ready_story, take_turn

AUTH = "Bearer good-token"


async def read_stream(response):
    return "".join([chunk.decode() if isinstance(chunk, bytes) else chunk async for chunk in response.body_iterator])


class PlayApiTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.client, self.story_id, self.model = await ready_story()
        for target, name in ((play_api, "get_supabase_client"), (chat_api, "get_supabase_client"),
                             (scenes_api, "get_supabase_client")):
            patcher = patch.object(target, name, return_value=self.client)
            patcher.start()
            self.addCleanup(patcher.stop)
        patcher = patch.object(play_api, "get_planner", return_value=planner_for(self.model))
        patcher.start()
        self.addCleanup(patcher.stop)

    def first_choice(self):
        return available_choices(load_context(self.client, self.story_id))[0]["id"]

    async def post(self, choice_id, request_id="turn-1"):
        request = play_api.PlayRequest(choice_id=choice_id, client_request_id=request_id)
        return await play_api.post_play(self.story_id, request, authorization=AUTH)

    async def test_get_returns_where_the_reader_is(self):
        response = await play_api.get_play(self.story_id, BackgroundTasks(), authorization=AUTH)
        self.assertEqual(set(response.data), {"beat_seq", "question", "choices", "preparing", "finished",
                                              "present_characters", "callbacks"})
        self.assertEqual(set(response.data["choices"][0]), {"id", "label", "lasting"})

    async def test_post_streams_the_scene_and_saves_the_turn(self):
        response = await self.post(self.first_choice())
        self.assertEqual(await read_stream(response), "숲길에 바람이 불었다.\n\n「가자.」")
        self.assertIsNone(response.background)  # not a major event
        self.assertEqual(self.client.story(self.story_id)["current_beat_seq"], 2)

    async def test_reaching_a_major_event_plans_the_next_segment_after_the_response(self):
        for _ in range(2):
            await take_turn(self.client, self.story_id, self.model)
        response = await self.post(self.first_choice(), "turn-3")
        await read_stream(response)
        self.assertEqual(response.background.func, plan_next_segment)
        tasks = BackgroundTasks()
        await play_api.get_play(self.story_id, tasks, authorization=AUTH)
        self.assertEqual([task.func for task in tasks.tasks], [plan_next_segment])  # still waiting: resume it

    async def test_a_choice_that_is_not_offered_is_a_409_before_streaming(self):
        with self.assertRaises(HTTPException) as caught:
            await self.post("made-up")
        self.assertEqual(caught.exception.status_code, 409)

    async def test_a_repeated_request_replays_the_saved_scene_without_the_model(self):
        await read_stream(await self.post(self.first_choice()))
        with patch.object(play_api, "get_planner", side_effect=AssertionError("must not call the model")):
            replay = await self.post("anything")
        self.assertEqual(await read_stream(replay), "숲길에 바람이 불었다.\n\n「가자.」")

    async def test_a_failure_while_streaming_ends_with_a_marker_and_saves_nothing(self):
        outage = ExternalServiceError("OpenRouter story scene", "일시적인 서버 문제가 발생했습니다.", "503")
        with patch.object(play_api, "get_planner", return_value=planner_for(FakeModel(fail_on={"stream": outage}))):
            text = await read_stream(await self.post(self.first_choice()))
        self.assertEqual(text, "\n[STREAM_ERROR:일시적인 서버 문제가 발생했습니다.]")
        self.assertEqual(self.client.story(self.story_id)["current_beat_seq"], 1)
        self.assertEqual(self.client.rows("scenes", client_request_id="turn-1"), [])

    async def test_post_with_text_writes_the_readers_own_action(self):
        request = play_api.PlayRequest(text="  세라를 바라본다  ", client_request_id="free-1")
        response = await play_api.post_play(self.story_id, request, authorization=AUTH)
        self.assertEqual(await read_stream(response), "숲길에 바람이 불었다.\n\n「가자.」")
        self.assertIn("interpret", self.model.kinds())
        user_scene = next(s for s in self.client.rows("scenes", client_request_id="free-1") if s["role"] == "user")
        self.assertEqual(user_scene["content"], "세라를 바라본다")

    def test_a_request_sends_a_choice_or_text_but_not_both(self):
        for fields in ({}, {"choice_id": "e1", "text": "간다"}, {"text": "   "}, {"text": "가" * 301}):
            with self.assertRaises(ValidationError, msg=fields):
                play_api.PlayRequest(**fields)

    async def test_an_outage_while_reading_the_input_is_a_503_before_streaming(self):
        outage = ExternalServiceError("OpenRouter story input", "일시적인 서버 문제가 발생했습니다.", "503")
        with patch.object(play_api, "get_planner", return_value=planner_for(FakeModel(fail_on={"interpret": outage}))):
            with self.assertRaises(HTTPException) as caught:
                await play_api.post_play(self.story_id, play_api.PlayRequest(text="간다"), authorization=AUTH)
        self.assertEqual((caught.exception.status_code, caught.exception.detail), (503, "일시적인 서버 문제가 발생했습니다."))

    async def test_undo_endpoint(self):
        await read_stream(await self.post(self.first_choice()))
        response = await play_api.undo_play(self.story_id, authorization=AUTH)
        self.assertEqual(response.data["beat_seq"], 1)
        with self.assertRaises(HTTPException) as caught:
            await play_api.undo_play(self.story_id, authorization=AUTH)
        self.assertEqual(caught.exception.status_code, 409)


class LegacyEndpointsTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.client, self.story_id, _ = await ready_story()
        for target in (chat_api, scenes_api):
            patcher = patch.object(target, "get_supabase_client", return_value=self.client)
            patcher.start()
            self.addCleanup(patcher.stop)

    async def test_free_chat_is_refused_for_a_skeleton_story(self):
        # The fake client's ids are not UUIDs; the request model itself is not what is under test.
        request = chat_api.ChatRequest.model_construct(story_id=self.story_id, message="hello", history=[], client_request_id=None)
        with patch.object(chat_api, "ChatService", side_effect=AssertionError("no LLM call")):
            with self.assertRaises(HTTPException) as caught:
                await chat_api.chat(request, authorization=AUTH)
            self.assertEqual(caught.exception.status_code, 409)
            with self.assertRaises(HTTPException) as caught:
                await chat_api.chat_stream(request, authorization=AUTH)
            self.assertEqual(caught.exception.status_code, 409)

    async def test_deleting_a_scene_is_refused(self):
        scene_id = self.client.rows("scenes", story_id=self.story_id)[0]["id"]
        with self.assertRaises(HTTPException) as caught:
            await scenes_api.delete_scene(self.story_id, scene_id, authorization=AUTH)
        self.assertEqual(caught.exception.status_code, 409)
        self.assertEqual(len(self.client.rows("scenes", story_id=self.story_id)), 1)

    async def test_adding_or_editing_a_scene_is_refused(self):
        scene_id = self.client.rows("scenes", story_id=self.story_id)[0]["id"]
        with self.assertRaises(HTTPException) as caught:
            await scenes_api.create_scene(self.story_id, SceneCreate(content="끼워 넣은 장면"), authorization=AUTH)
        self.assertEqual(caught.exception.status_code, 409)
        with self.assertRaises(HTTPException) as caught:
            await scenes_api.update_scene(self.story_id, scene_id, {"beat_id": None}, authorization=AUTH)
        self.assertEqual(caught.exception.status_code, 409)
        self.assertEqual(len(self.client.rows("scenes", story_id=self.story_id)), 1)

    async def test_who_is_present_comes_from_the_state_without_an_llm_call(self):
        with patch.object(scenes_api, "ChatService", side_effect=AssertionError("no LLM call")):
            response = await scenes_api.analyze_scene(self.story_id, "본문", ["카엘"], authorization=AUTH)
        self.assertEqual(response.data, {"present_characters": ["카엘", "세라"], "important_characters": ["카엘", "세라"]})



class BeforeMigrationTest(unittest.TestCase):
    """Deploying before the migration must leave legacy stories working as before."""

    class NoModeColumn:
        def __init__(self, row):
            self.row = row

        def table(self, _name):
            outer = self

            class Query:
                def select(self, columns):
                    self.columns = columns
                    return self

                def eq(self, *_args):
                    return self

                def single(self):
                    return self

                def limit(self, *_args):
                    return self

                def execute(self):
                    if "mode" in [column.strip() for column in self.columns.split(",")]:
                        raise RuntimeError('column stories.mode does not exist')
                    from story_fakes import FakeResponse
                    return FakeResponse(outer.row)

            return Query()

    def test_chat_keeps_the_story_settings_without_the_mode_column(self):
        client = self.NoModeColumn({"llm_model": "pro", "narrative_type": "ensemble", "user_id": "user-1"})
        self.assertEqual(chat_api._get_story_metadata(client, "story-1"),
                         {"llm_model": "pro", "narrative_type": "ensemble", "user_id": "user-1"})

    def test_scenes_treat_every_story_as_legacy_without_the_mode_column(self):
        self.assertFalse(scenes_api._is_skeleton_story(self.NoModeColumn(None), "story-1"))

if __name__ == "__main__":
    unittest.main()
