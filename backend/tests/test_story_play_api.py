import os
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
                                              "present_characters", "callbacks", "media_pending"})
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
        self.assertEqual(response.background.func, play_api.after_turn)
        tasks = BackgroundTasks()
        await play_api.get_play(self.story_id, tasks, authorization=AUTH)
        self.assertEqual([task.func for task in tasks.tasks], [plan_next_segment])  # still waiting: resume it

    async def test_a_tense_major_event_has_its_media_pending_when_the_scene_arrives(self):
        for turn_number in range(1, 30):
            if not available_choices(load_context(self.client, self.story_id)):
                await plan_next_segment(self.story_id, planner_for(self.model), self.client)  # the background task
            response = await self.post(self.first_choice(), f"turn-{turn_number}")
            await read_stream(response)
            if self.client.rows("media_jobs"):
                break
        # e03 (intensity 4) is the first such event; e01 and e02 are calmer and got nothing
        scene = self.client.rows("scenes", id=self.client.rows("media_jobs")[0]["scene_id"])[0]
        self.assertEqual(scene["beat_id"], next(beat["id"] for beat in self.client.rows("story_beats")
                                                if beat.get("spine_event_id") == "e03"))
        image, bgm = self.client.rows("media_jobs")
        self.assertEqual((image["media_type"], bgm["media_type"]), ("image", "bgm"))
        self.assertIn("장면: e03", image["prompt"])  # from the plan, not the prose
        self.assertIn("Tension 4 of 5", bgm["prompt"])
        status = await play_api.get_play(self.story_id, BackgroundTasks(), authorization=AUTH)
        self.assertTrue(status.data["media_pending"])  # before the response's background task has run
        self.assertEqual(response.background.func, play_api.after_turn)

    async def test_a_question_echoed_by_the_model_is_neither_shown_nor_saved(self):
        question = "세라에게 무엇을 말할 것인가"  # the question of the next scene card
        echoing = FakeModel()
        echoing.stream_pieces = ("숲길에 바람이 불었다.", "\n\n「가자.」", "\n\n***\n\n", question + "?")
        with patch.object(play_api, "get_planner", return_value=planner_for(echoing)):
            text = await read_stream(await self.post(self.first_choice()))
        self.assertEqual(text, "숲길에 바람이 불었다.\n\n「가자.」")
        ai_scene = next(s for s in self.client.rows("scenes", client_request_id="turn-1") if s["role"] == "ai")
        self.assertEqual(ai_scene["content"], text)

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

    async def test_a_second_turn_sent_while_one_is_being_written_is_refused_before_the_model(self):
        first = await self.post(self.first_choice(), "turn-1")  # its stream is not read yet: the turn is in progress
        with patch.object(play_api, "get_planner", side_effect=AssertionError("must not call the model")):
            with self.assertRaises(HTTPException) as caught:
                await self.post(self.first_choice(), "turn-2")
        self.assertEqual(caught.exception.status_code, 409)
        await read_stream(first)  # the first turn finishes and frees the story
        self.assertIsNone(self.client.story(self.story_id)["turn_lock_owner"])

    async def test_a_failed_turn_frees_the_story(self):
        outage = ExternalServiceError("OpenRouter story scene", "일시적인 서버 문제가 발생했습니다.", "503")
        with patch.object(play_api, "get_planner", return_value=planner_for(FakeModel(fail_on={"stream": outage}))):
            await read_stream(await self.post(self.first_choice()))
        with self.assertRaises(HTTPException):
            await self.post("made-up", "turn-2")  # refused before the stream (409): must free the story too
        self.assertIsNone(self.client.story(self.story_id)["turn_lock_owner"])

    async def test_written_actions_stop_at_the_daily_limit_and_undo_does_not_give_them_back(self):
        async def write(request_id):
            request = play_api.PlayRequest(text="세라를 바라본다", client_request_id=request_id)
            return await read_stream(await play_api.post_play(self.story_id, request, authorization=AUTH))

        with patch.dict(os.environ, {"DIRECT_INPUT_DAILY_LIMIT": "1"}):
            await write("free-1")
            await play_api.undo_play(self.story_id, authorization=AUTH)
            with self.assertRaises(HTTPException) as caught:
                await write("free-2")
            self.assertEqual(caught.exception.status_code, 429)
            await read_stream(await self.post(self.first_choice(), "turn-3"))  # choices are never limited
        self.assertEqual(self.client.story(self.story_id)["current_beat_seq"], 2)

    async def test_each_turn_is_recorded_for_the_measurements(self):
        await read_stream(await self.post(self.first_choice(), "turn-1"))
        request = play_api.PlayRequest(text="세라를 바라본다", client_request_id="free-1")
        await read_stream(await play_api.post_play(self.story_id, request, authorization=AUTH))
        choice_row, free_row = self.client.rows("play_turn_log", story_id=self.story_id)
        ai_scene = next(s for s in self.client.rows("scenes", client_request_id="turn-1") if s["role"] == "ai")
        self.assertEqual((choice_row["kind"], choice_row["outcome"], choice_row["scene_id"], choice_row["beat_seq"]),
                         ("choice", "saved", ai_scene["id"], 2))
        self.assertEqual(choice_row["choices_offered"], 3)
        self.assertIn("독자의 뜻:", choice_row["brief"])
        self.assertTrue(all(isinstance(choice_row[key], int) for key in ("prepare_ms", "first_chunk_ms", "stream_ms")))
        self.assertEqual((free_row["kind"], free_row["input_judgement"]), ("free", "holds"))

    async def test_a_failed_turn_is_recorded_with_its_error(self):
        outage = ExternalServiceError("OpenRouter story scene", "일시적인 서버 문제가 발생했습니다.", "503")
        with patch.object(play_api, "get_planner", return_value=planner_for(FakeModel(fail_on={"stream": outage}))):
            await read_stream(await self.post(self.first_choice()))
        (row,) = self.client.rows("play_turn_log", story_id=self.story_id)
        self.assertEqual((row["outcome"], row["scene_id"]), ("failed", None))
        self.assertIn("ExternalServiceError", row["error"])

    async def test_a_turn_is_saved_even_if_it_cannot_be_recorded(self):
        original = self.client.insert_rows

        def no_log(table_name, payload):
            if table_name == "play_turn_log":
                raise RuntimeError("table missing")
            return original(table_name, payload)

        self.client.insert_rows = no_log
        await read_stream(await self.post(self.first_choice()))
        self.assertEqual(self.client.story(self.story_id)["current_beat_seq"], 2)
        self.assertIsNone(self.client.story(self.story_id)["turn_lock_owner"])

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
