import unittest
from unittest.mock import patch

from app.services.story_generation import Planner, create_skeleton_story, run_generation
from app.services import story_play
from app.services.story_play import (
    EchoGuard,
    PlayError,
    strip_echoed_question,
    available_choices,
    finish_turn,
    load_context,
    needs_next_segment,
    plan_next_segment,
    planning_is_stalled,
    play_status,
    prepare_turn,
    stream_turn,
    undo_last_turn,
)
from story_fakes import SEGMENT2, FakeClient, FakeModel, story_request


def planner_for(model):
    return Planner(model.complete_json, model.complete_text, model.stream_text)


async def ready_story(model=None):
    """A generated story whose reader stands right after the opening scene."""
    client, model = FakeClient(), model or FakeModel()
    story, _ = create_skeleton_story(client, story_request(), "user-1")
    await run_generation(story["id"], planner_for(model), client)
    return client, story["id"], model


async def take_turn(client, story_id, model, choice_id=None, request_id=None):
    """Pick a choice (the first lasting one unless given), stream the scene and save it. Returns (turn, prose)."""
    planner = planner_for(model)
    if choice_id is None:
        choices = available_choices(load_context(client, story_id))
        choice_id = next((choice["id"] for choice in choices if choice["lasting"]), choices[0]["id"])
    turn = await prepare_turn(client, story_id, choice_id, planner)
    prose = "".join([chunk async for chunk in stream_turn(client, turn, planner)])
    finish_turn(client, turn, prose, request_id)
    return turn, prose


class StatusTest(unittest.IsolatedAsyncioTestCase):
    async def test_after_the_opening_the_reader_gets_three_varied_choices_and_the_question(self):
        client, story_id, _ = await ready_story()
        status = play_status(load_context(client, story_id))
        self.assertEqual(status["beat_seq"], 1)
        self.assertEqual(status["question"], "세라의 망설임을 캐물을 것인가")
        self.assertEqual(len(status["choices"]), 3)
        self.assertEqual({choice["lasting"] for choice in status["choices"]}, {True, False})  # item 8: the app can mark lasting ones
        self.assertFalse(status["preparing"] or status["finished"])
        self.assertEqual(status["present_characters"], ["카엘", "세라"])

    async def test_a_story_still_generating_cannot_be_played(self):
        client = FakeClient()
        story, _ = create_skeleton_story(client, story_request(), "user-1")
        with self.assertRaises(PlayError) as caught:
            load_context(client, story["id"])
        self.assertEqual(caught.exception.status_code, 409)


class TurnTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.client, self.story_id, self.model = await ready_story()

    async def test_a_turn_applies_the_choice_writes_the_next_scene_and_saves_both(self):
        turn, prose = await take_turn(self.client, self.story_id, self.model, request_id="turn-1")
        self.assertEqual(prose, "숲길에 바람이 불었다.\n\n「가자.」")
        story = self.client.story(self.story_id)
        self.assertEqual(story["current_beat_seq"], 2)
        self.assertEqual(story["world_state"]["chars"]["카엘"]["at"], "숲")  # the next card moves 카엘
        chosen_fact = turn.choice["events"][0]["fact"]
        self.assertEqual(story["world_state"]["facts"][chosen_fact]["origin"], "choice")
        user_scene, ai_scene = sorted(self.client.rows("scenes", client_request_id="turn-1"), key=lambda scene: scene["sequence"])
        self.assertEqual((user_scene["role"], user_scene["content"]), ("user", turn.choice["label"]))
        self.assertEqual(ai_scene["events"][0]["origin"], "choice")
        self.assertEqual(ai_scene["events"][-1], {"type": "move", "who": "카엘", "to": "숲", "origin": "scene"})
        self.assertEqual(story["current_scene_id"], ai_scene["id"])

    async def test_the_scene_writer_gets_the_brief_the_previous_tail_and_the_question(self):
        await take_turn(self.client, self.story_id, self.model)
        prompt = [user for kind, _, user in self.model.calls if kind == "stream"][-1]
        self.assertIn("반드시: 카엘 이(가) 숲(으)로 간다", prompt)
        self.assertIn("독자에게 묻는 것: 세라에게 무엇을 말할 것인가", prompt)
        self.assertIn("앞 장면은 이렇게 끝났다:\n", prompt)
        self.assertIn("「내일이면 떠나는군요.」", prompt)  # the end of the opening scene

    async def test_earlier_choices_the_next_scene_carries_are_shown_as_callbacks(self):
        turn, _ = await take_turn(self.client, self.story_id, self.model)
        chosen_fact = turn.choice["events"][0]["fact"]
        status = play_status(load_context(self.client, self.story_id))
        self.assertEqual(status["callbacks"], [chosen_fact])  # item 9: "당신의 선택: ..."
        prompt = [user for kind, _, user in self.model.calls if kind == "stream"][-1]
        self.assertIn(f"독자의 선택: {chosen_fact}", prompt)

    async def test_the_status_shows_the_path_and_which_choices_stay(self):
        status = play_status(load_context(self.client, self.story_id))
        self.assertEqual(status["path"], [{"seq": 1, "label": "", "lasting": False}])  # the opening, reached by no choice
        lasting, _ = await take_turn(self.client, self.story_id, self.model)
        choices = available_choices(load_context(self.client, self.story_id))
        quiet_id = next(choice["id"] for choice in choices if not choice["lasting"])
        quiet, _ = await take_turn(self.client, self.story_id, self.model, choice_id=quiet_id)
        status = play_status(load_context(self.client, self.story_id))
        self.assertEqual(status["path"], [
            {"seq": 1, "label": "", "lasting": False},
            {"seq": 2, "label": lasting.choice["label"], "lasting": True},
            {"seq": 3, "label": quiet.choice["label"], "lasting": False},
        ])

    async def test_a_beat_saved_before_the_path_was_recorded_gets_it_from_the_previous_choice(self):
        turn, _ = await take_turn(self.client, self.story_id, self.model)
        beat = next(beat for beat in self.client.rows("story_beats", story_id=self.story_id) if beat["seq"] == 2)
        beat["card"] = {key: value for key, value in beat["card"].items() if key not in ("chosen_label", "chosen_lasting")}
        path = play_status(load_context(self.client, self.story_id))["path"]
        self.assertEqual(path[-1], {"seq": 2, "label": turn.choice["label"], "lasting": True})

    async def test_an_undone_turn_leaves_the_path(self):
        await take_turn(self.client, self.story_id, self.model)
        undo_last_turn(self.client, self.story_id)
        path = play_status(load_context(self.client, self.story_id))["path"]
        self.assertEqual([step["seq"] for step in path], [1])

    async def test_a_choice_that_is_not_offered_is_refused(self):
        with self.assertRaises(PlayError) as caught:
            await prepare_turn(self.client, self.story_id, "made-up", planner_for(self.model))
        self.assertEqual(caught.exception.status_code, 409)

    async def test_two_turns_sent_at_once_cannot_both_be_saved(self):
        planner = planner_for(self.model)
        choice_id = available_choices(load_context(self.client, self.story_id))[0]["id"]
        first = await prepare_turn(self.client, self.story_id, choice_id, planner)
        second = await prepare_turn(self.client, self.story_id, choice_id, planner)
        finish_turn(self.client, first, "첫 번째", "a")
        with self.assertRaises(PlayError) as caught:
            finish_turn(self.client, second, "두 번째", "b")
        self.assertEqual(caught.exception.status_code, 409)
        self.assertEqual(self.client.rows("scenes", client_request_id="b"), [])

    async def test_a_failed_save_puts_the_story_back(self):
        planner = planner_for(self.model)
        before = dict(self.client.story(self.story_id))
        turn = await prepare_turn(self.client, self.story_id, available_choices(load_context(self.client, self.story_id))[0]["id"], planner)
        original = self.client.insert_rows

        def failing_scenes(table_name, payload):
            if table_name == "scenes":
                raise RuntimeError("database is down")
            return original(table_name, payload)

        beats_before = [dict(beat) for beat in self.client.rows("story_beats", story_id=self.story_id)]
        self.client.insert_rows = failing_scenes
        with self.assertRaises(RuntimeError):
            finish_turn(self.client, turn, "본문", "c")
        story = self.client.story(self.story_id)
        self.assertEqual((story["current_beat_seq"], story["world_state"]), (before["current_beat_seq"], before["world_state"]))
        self.assertEqual(self.client.rows("story_beats", story_id=self.story_id), beats_before)  # the beat is not written


class MajorEventTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.client, self.story_id, self.model = await ready_story()
        for _ in range(2):  # the two planned scenes of the first segment
            await take_turn(self.client, self.story_id, self.model)
        self.turn, _ = await take_turn(self.client, self.story_id, self.model)  # reaches major event e02

    def test_reaching_a_major_event_creates_its_beat_and_asks_for_the_next_segment(self):
        story = self.client.story(self.story_id)
        self.assertEqual(story["current_beat_seq"], 4)
        beat = next(beat for beat in self.client.rows("story_beats", story_id=self.story_id) if beat["seq"] == 4)
        self.assertEqual((beat["spine_event_id"], beat["status"]), ("e02", "written"))
        self.assertEqual(story["world_state"]["items"]["은빛 단검"], "카엘")  # e02 hands the dagger over
        self.assertTrue(needs_next_segment(self.turn))

    async def test_choices_wait_until_the_next_segment_is_planned(self):
        context = load_context(self.client, self.story_id)
        status = play_status(context)
        self.assertEqual((status["preparing"], status["choices"]), (True, []))
        self.assertTrue(planning_is_stalled(self.client, context))

        await plan_next_segment(self.story_id, planner_for(self.model), self.client)
        context = load_context(self.client, self.story_id)
        status = play_status(context)
        self.assertFalse(status["preparing"])
        self.assertEqual(status["question"], "단검을 받아 들 것인가")
        self.assertEqual(len(status["choices"]), 3)
        self.assertFalse(planning_is_stalled(self.client, context))
        planned = [beat for beat in self.client.rows("story_beats", story_id=self.story_id) if beat["seq"] == 5]
        self.assertEqual(planned[0]["card"]["title"], "숲의 밤")
        self.assertIsNone(self.client.plan(self.story_id)["lease_owner"])

    async def test_planning_twice_does_nothing_the_second_time(self):
        await plan_next_segment(self.story_id, planner_for(self.model), self.client)
        calls = len(self.model.calls)
        await plan_next_segment(self.story_id, planner_for(self.model), self.client)
        self.assertEqual(len(self.model.calls), calls)

    async def test_a_plan_that_fails_part_way_is_planned_again(self):
        original = self.client.insert_rows

        def failing_beats(table_name, payload):
            if table_name == "story_beats":
                raise RuntimeError("database is down")
            return original(table_name, payload)

        self.client.insert_rows = failing_beats
        await plan_next_segment(self.story_id, planner_for(self.model), self.client)
        self.client.insert_rows = original
        context = load_context(self.client, self.story_id)
        self.assertTrue(play_status(context)["preparing"])  # the choices were not kept without their segment
        self.client.plan(self.story_id)["lease_until"] = None  # the back-off is over
        self.assertTrue(planning_is_stalled(self.client, context))

    async def test_a_plan_finished_after_an_undo_is_dropped(self):
        planner, events = planner_for(self.model), []
        original_rpc = self.client.rpc

        def undo_first(name, params):
            if name == "save_next_segment" and not events:
                events.append(name)
                undo_last_turn(self.client, self.story_id)  # the reader undid while the segment was being planned
            return original_rpc(name, params)

        self.client.rpc = undo_first
        await plan_next_segment(self.story_id, planner, self.client)
        self.assertEqual(sorted(b["seq"] for b in self.client.rows("story_beats", story_id=self.story_id)), [1, 2, 3])

    async def test_a_failed_plan_backs_off_instead_of_retrying_at_once(self):
        failing = FakeModel(fail_on={"segment": RuntimeError("model down")})
        await plan_next_segment(self.story_id, planner_for(failing), self.client)
        self.assertFalse(planning_is_stalled(self.client, load_context(self.client, self.story_id)))
        self.assertIn("RuntimeError", self.client.plan(self.story_id)["retry_log"][-1]["error"])

    async def test_the_last_major_event_finishes_the_story(self):
        plan = self.client.plan(self.story_id)
        plan["spine"]["events"] = plan["spine"]["events"][:2]  # pretend e02 was the ending
        undo_last_turn(self.client, self.story_id)  # back to just before e02
        turn, _ = await take_turn(self.client, self.story_id, self.model)
        self.assertFalse(needs_next_segment(turn))
        status = play_status(load_context(self.client, self.story_id))
        self.assertEqual((status["finished"], status["choices"]), (True, []))
        self.assertEqual(self.client.story(self.story_id)["status"], "completed")


class PlanAheadTest(unittest.IsolatedAsyncioTestCase):
    """At the last scene before a major event, the segment after it is planned while the reader reads."""

    async def asyncSetUp(self):
        self.client, self.story_id, self.model = await ready_story()
        self.addCleanup(story_play._drafts.clear)
        for _ in range(2):  # the two planned scenes of the first segment: e02 comes next
            await take_turn(self.client, self.story_id, self.model)

    def segment_calls(self):
        return self.model.kinds().count("segment")

    async def reach_e02_quietly(self):
        quiet = next(c for c in available_choices(load_context(self.client, self.story_id)) if not c["lasting"])
        await take_turn(self.client, self.story_id, self.model, choice_id=quiet["id"])

    async def test_the_segment_planned_ahead_is_used_without_planning_again(self):
        context = load_context(self.client, self.story_id)
        self.assertEqual(story_play.next_major_event(context)[1]["id"], "e02")
        await story_play.plan_ahead(self.story_id, planner_for(self.model), self.client)
        self.assertEqual(story_play._drafts[self.story_id]["event_id"], "e02")
        await self.reach_e02_quietly()
        calls = self.segment_calls()
        await plan_next_segment(self.story_id, planner_for(self.model), self.client)
        self.assertEqual(self.segment_calls(), calls)  # no model call: the draft held
        status = play_status(load_context(self.client, self.story_id))
        self.assertEqual((status["preparing"], status["question"], len(status["choices"])),
                         (False, "단검을 받아 들 것인가", 3))

    async def test_a_draft_that_no_longer_holds_is_planned_again(self):
        await story_play.plan_ahead(self.story_id, planner_for(self.model), self.client)
        await self.reach_e02_quietly()
        calls = self.segment_calls()
        with patch.object(story_play, "check_planned_segment", return_value=[("s1", "카엘이 숲에 없다")]):
            await plan_next_segment(self.story_id, planner_for(self.model), self.client)
        self.assertEqual(self.segment_calls(), calls + 1)
        self.assertFalse(play_status(load_context(self.client, self.story_id))["preparing"])

    async def test_nothing_is_planned_ahead_in_the_middle_of_a_segment(self):
        undo_last_turn(self.client, self.story_id)  # back to the first scene: another planned scene follows
        calls = len(self.model.calls)
        await story_play.plan_ahead(self.story_id, planner_for(self.model), self.client)
        self.assertEqual((len(self.model.calls), story_play._drafts), (calls, {}))


class ReplanTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.client, self.story_id, self.model = await ready_story()
        first = next(beat for beat in self.client.rows("story_beats", story_id=self.story_id) if beat["seq"] == 1)
        breaking = {"id": "e9", "label": "도윤을 왕성으로 부른다", "kind": "action",
                    "events": [{"type": "move", "who": "도윤", "to": "왕성"}]}
        first["card"]["choices"] = [first["card"]["choices"][0], breaking]

    def planned_titles(self):
        beats = sorted(self.client.rows("story_beats", story_id=self.story_id), key=lambda beat: beat["seq"])
        return [(beat["seq"], beat["card"].get("title"), beat["status"]) for beat in beats]

    async def test_a_choice_that_breaks_the_rest_of_the_segment_plans_it_again(self):
        segment_calls = self.model.kinds().count("segment")
        offered = {choice["id"]: choice for choice in available_choices(load_context(self.client, self.story_id))}
        self.assertTrue(offered["e9"]["replan"])
        self.model.script["segment"] = [SEGMENT2]  # the replanned segment: one scene, "숲의 밤"
        await take_turn(self.client, self.story_id, self.model, choice_id="e9")
        self.assertEqual(self.model.kinds().count("segment"), segment_calls + 1)
        self.assertEqual(self.client.story(self.story_id)["world_state"]["chars"]["도윤"]["at"], "왕성")
        self.assertEqual(self.planned_titles()[1:], [(2, "숲의 밤", "written")])  # the old planned scenes are gone

    async def test_a_turn_that_is_never_saved_keeps_the_planned_segment(self):
        before = self.planned_titles()
        await prepare_turn(self.client, self.story_id, "e9", planner_for(self.model))  # e.g. the stream broke
        self.assertEqual(self.planned_titles(), before)


class UndoTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.client, self.story_id, self.model = await ready_story()
        self.before = dict(self.client.story(self.story_id))

    async def test_undo_restores_the_state_and_removes_the_turns_scenes(self):
        await take_turn(self.client, self.story_id, self.model, request_id="turn-1")
        undone = undo_last_turn(self.client, self.story_id)
        story = self.client.story(self.story_id)
        self.assertEqual((story["current_beat_seq"], story["world_state"]), (1, self.before["world_state"]))
        self.assertEqual(self.client.rows("scenes", client_request_id="turn-1"), [])
        beat = next(beat for beat in self.client.rows("story_beats", story_id=self.story_id) if beat["seq"] == 2)
        self.assertEqual(beat["status"], "planned")
        self.assertNotIn("state_before", beat["card"])
        self.assertEqual(len(play_status(undone)["choices"]), 3)

    async def test_a_different_choice_can_be_taken_after_undo(self):
        choices = available_choices(load_context(self.client, self.story_id))
        await take_turn(self.client, self.story_id, self.model, choice_id=choices[0]["id"])
        undo_last_turn(self.client, self.story_id)
        await take_turn(self.client, self.story_id, self.model, choice_id=choices[1]["id"])
        self.assertEqual(self.client.story(self.story_id)["current_beat_seq"], 2)

    async def test_undoing_a_major_event_removes_it_and_what_was_planned_after_it(self):
        for _ in range(3):
            await take_turn(self.client, self.story_id, self.model)
        await plan_next_segment(self.story_id, planner_for(self.model), self.client)
        undo_last_turn(self.client, self.story_id)
        seqs = sorted(beat["seq"] for beat in self.client.rows("story_beats", story_id=self.story_id))
        self.assertEqual(seqs, [1, 2, 3])
        self.assertEqual(self.client.story(self.story_id)["current_beat_seq"], 3)

    def test_the_opening_cannot_be_undone(self):
        with self.assertRaises(PlayError) as caught:
            undo_last_turn(self.client, self.story_id)
        self.assertEqual(caught.exception.status_code, 409)


class EchoedQuestionTest(unittest.TestCase):
    QUESTION = "이란의 뜻을 안 카엘은 조사를 어떻게 함께 이어갈까?"

    def test_a_question_printed_at_the_end_is_dropped_with_its_separator(self):
        scene = "카엘은 벽을 보았다.\n\n이란이 물었다.\n\n***\n\n" + self.QUESTION
        self.assertEqual(strip_echoed_question(scene, self.QUESTION), "카엘은 벽을 보았다.\n\n이란이 물었다.")

    def test_a_scene_that_only_talks_about_it_is_kept(self):
        scene = "카엘은 벽을 보았다.\n\n그는 이란의 뜻을 안 카엘은 조사를 어떻게 함께 이어갈까 하는 물음을 오래 붙들고, 새벽이 올 때까지 성벽 아래를 걸었다."
        self.assertEqual(strip_echoed_question(scene, self.QUESTION), scene)
        self.assertEqual(strip_echoed_question(scene, None), scene)

    def test_streaming_never_sends_the_echo_and_sends_everything_else(self):
        scene = "첫 문단이다.\n\n둘째 문단이다.\n\n셋째 문단이다.\n\n***\n\n" + self.QUESTION
        guard, sent = EchoGuard(self.QUESTION), ""
        for start in range(0, len(scene), 7):  # arbitrary chunk boundaries
            sent += guard.feed(scene[start:start + 7])
        self.assertNotIn("***", sent)
        sent += guard.finish()
        self.assertEqual(sent, "첫 문단이다.\n\n둘째 문단이다.\n\n셋째 문단이다.")
        self.assertEqual(guard.prose, sent)

    def test_streaming_a_clean_scene_sends_it_unchanged(self):
        scene = "숲길에 바람이 불었다.\n\n「가자.」\n\n둘은 걸었다."
        guard = EchoGuard(self.QUESTION)
        sent = "".join(guard.feed(piece) for piece in scene.split(" ")[:1] + [" " + p for p in scene.split(" ")[1:]])
        self.assertEqual(sent + guard.finish(), scene)


if __name__ == "__main__":
    unittest.main()
