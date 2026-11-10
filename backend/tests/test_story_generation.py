import asyncio
import unittest
from datetime import datetime, timedelta, timezone

from app.llm_models import PRIMARY_FAST_LLM_MODEL, PRIMARY_PRO_LLM_MODEL
from app.services import story_generation as generation
from app.services.external_errors import ExternalServiceError
from app.services.story_generation import (
    FAILURE_MESSAGE,
    GenerationLimitReached,
    Job,
    LeaseLost,
    Planner,
    RequestIdConflict,
    claim_generation,
    create_skeleton_story,
    generation_status,
    is_stalled,
    parse_json_object,
    parse_timestamp,
    reset_failed_generation,
    run_generation,
)
from app.services.story_planner import PlanFormatError
from story_fakes import (
    BETRAYAL_REVEALED,
    SEGMENT,
    SEGMENT_STUCK,
    SPINE,
    SPINE_WITH_PROBLEM,
    WORLD,
    FakeClient,
    FakeModel,
    story_request,
)


def planner_for(model):
    return Planner(model.complete_json, model.complete_text)


def new_story(client, user_id="user-1", **overrides):
    story, _ = create_skeleton_story(client, story_request(**overrides), user_id)
    return story["id"]


def expire_lease(client, story_id):
    client.plan(story_id)["lease_until"] = (datetime.now(timezone.utc) - timedelta(seconds=1)).isoformat()


class FullRunTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.client = FakeClient()
        self.story_id = new_story(self.client, llm_model=PRIMARY_FAST_LLM_MODEL)
        self.model = FakeModel()
        await run_generation(self.story_id, planner_for(self.model), self.client)

    def test_every_step_runs_once_in_order_with_the_right_model(self):
        self.assertEqual(self.model.kinds(), ["world", "spine", "segment", "scene"])
        models = {kind: model for kind, model, _ in self.model.calls}
        self.assertEqual(models["world"], PRIMARY_FAST_LLM_MODEL)
        self.assertEqual(models["spine"], PRIMARY_PRO_LLM_MODEL)
        self.assertEqual(models["segment"], PRIMARY_FAST_LLM_MODEL)

    def test_plan_is_ready_and_releases_its_lease(self):
        plan = self.client.plan(self.story_id)
        self.assertEqual((plan["status"], plan["step"], plan["error"]), ("ready", "opening", None))
        self.assertIsNone(plan["lease_owner"])
        self.assertEqual([event["id"] for event in plan["spine"]["events"]], ["e01", "e02", "e03", "e04", "e05"])
        self.assertEqual(plan["world"]["facts"], [BETRAYAL_REVEALED])

    def test_story_becomes_active_with_its_first_scene_and_state(self):
        story = self.client.story(self.story_id)
        self.assertEqual((story["status"], story["title"], story["current_beat_seq"], story["total_scenes"]), ("active", "은빛 단검", 1, 1))
        (scene,) = self.client.rows("scenes", story_id=self.story_id)
        self.assertEqual(story["current_scene_id"], scene["id"])
        self.assertEqual(scene["events"], [{"type": "act", "who": "카엘", "with": "세라"}])
        self.assertEqual(story["world_state"]["chars"]["도윤"], {"alive": True, "at": "숲"})

    def test_beat_cards_hold_the_first_event_and_the_first_segment(self):
        beats = sorted(self.client.rows("story_beats", story_id=self.story_id), key=lambda beat: beat["seq"])
        self.assertEqual([(beat["seq"], beat["spine_event_id"], beat["status"]) for beat in beats],
                         [(1, "e01", "written"), (2, None, "planned"), (3, None, "planned")])
        self.assertEqual(len(beats[0]["card"]["choices"]), 4)
        self.assertEqual(self.client.rows("scenes", story_id=self.story_id)[0]["beat_id"], beats[0]["id"])

    def test_characters_are_created_and_linked_with_their_roles(self):
        links = self.client.rows("story_characters", story_id=self.story_id)
        names = {row["id"]: row["name"] for row in self.client.tables["characters"]}
        self.assertEqual({names[link["character_id"]]: link["role_in_story"] for link in links},
                         {"카엘": "protagonist", "세라": "antagonist", "도윤": "supporting"})

    def test_the_scene_writer_never_sees_the_ending(self):
        scene_prompt = next(user for kind, _, user in self.model.calls if kind == "scene")
        self.assertNotIn(SPINE["ending"], scene_prompt)
        self.assertIn("반드시: 카엘 이(가) 세라와(과) 마주하여 직접 행동한다", scene_prompt)
        self.assertIn("복선 심기: 세라의 망설임", scene_prompt)

    def test_status_for_the_app_hides_the_plan(self):
        self.assertEqual(generation_status(self.client.plan(self.story_id)),
                         {"status": "ready", "step": "opening", "error": None, "attempts": 0})


class RepairAndFailureTest(unittest.IsolatedAsyncioTestCase):
    async def test_only_the_events_with_problems_are_asked_again(self):
        client, model = FakeClient(), FakeModel(spines=(SPINE_WITH_PROBLEM,))
        story_id = new_story(client)
        await run_generation(story_id, planner_for(model), client)
        self.assertEqual(model.kinds(), ["world", "spine", "repair", "segment", "scene"])
        repair_prompt = model.calls[2][2]
        self.assertIn("e04: 원인(because)이 없다", repair_prompt)
        self.assertEqual(client.plan(story_id)["status"], "ready")

    async def test_a_segment_that_never_arrives_is_asked_again_with_what_is_missing(self):
        client, model = FakeClient(), FakeModel(segments=(SEGMENT_STUCK, SEGMENT))
        story_id = new_story(client)
        await run_generation(story_id, planner_for(model), client)
        self.assertEqual(model.kinds(), ["world", "spine", "segment", "segment", "scene"])
        self.assertIn("구간이 끝나도 갖춰지지 않는다: 도윤 와(과) 카엘 이(가) 같은 장소에 있다", model.calls[3][2])

    async def test_three_failed_attempts_give_up_with_a_user_facing_message(self):
        client = FakeClient()
        broken = {**WORLD, "items": [{"name": "은빛 단검", "holder": "하린"}]}
        model = FakeModel(world=broken)
        story_id = new_story(client)
        await run_generation(story_id, planner_for(model), client)
        plan = client.plan(story_id)
        self.assertEqual((plan["status"], plan["attempts"], plan["error"], plan["lease_owner"]), ("failed", 3, FAILURE_MESSAGE, None))
        self.assertEqual(client.story(story_id)["status"], "failed")
        self.assertEqual(model.kinds(), ["world"] * 6)  # two tries per attempt, three attempts

    async def test_an_external_error_keeps_its_own_message_and_retries_only_the_failed_step(self):
        client = FakeClient()
        outage = ExternalServiceError("OpenRouter story scene", "일시적인 서버 문제가 발생했습니다.", "503")
        model = FakeModel(fail_on={"scene": outage})
        story_id = new_story(client)
        await run_generation(story_id, planner_for(model), client)
        self.assertEqual(model.kinds(), ["world", "spine", "segment", "scene", "scene", "scene"])
        self.assertEqual(client.plan(story_id)["error"], "일시적인 서버 문제가 발생했습니다.")

    async def test_a_failed_generation_can_be_queued_again(self):
        client = FakeClient()
        story_id = new_story(client)
        self.assertFalse(reset_failed_generation(client, story_id))  # not failed yet
        client.plan(story_id).update({"status": "failed", "attempts": 3, "error": FAILURE_MESSAGE})
        self.assertTrue(reset_failed_generation(client, story_id))
        plan = client.plan(story_id)
        self.assertEqual((plan["status"], plan["attempts"], plan["error"]), ("queued", 0, None))
        self.assertEqual(client.story(story_id)["status"], "generating")


class ResumeTest(unittest.IsolatedAsyncioTestCase):
    async def test_a_run_that_dies_resumes_from_the_next_step(self):
        client = FakeClient()
        story_id = new_story(client)
        dying = FakeModel(fail_on={"segment": asyncio.CancelledError()})  # the process stops mid-step
        with self.assertRaises(asyncio.CancelledError):
            await run_generation(story_id, planner_for(dying), client)
        self.assertEqual((client.plan(story_id)["status"], client.plan(story_id)["step"]), ("running", "spine"))

        survivor = FakeModel()
        await run_generation(story_id, planner_for(survivor), client)
        self.assertEqual(survivor.calls, [])  # the dead run's lease is still live

        expire_lease(client, story_id)
        await run_generation(story_id, planner_for(survivor), client)
        self.assertEqual(survivor.kinds(), ["segment", "scene"])  # world and spine are not made again
        self.assertEqual(client.plan(story_id)["status"], "ready")

    async def test_a_written_opening_scene_is_not_written_again(self):
        client = FakeClient()
        story_id = new_story(client)
        await run_generation(story_id, planner_for(FakeModel()), client)
        plan = client.plan(story_id)
        plan.update({"status": "running", "step": "segment", "lease_owner": "dead-run"})
        expire_lease(client, story_id)
        model = FakeModel()
        await run_generation(story_id, planner_for(model), client)
        self.assertEqual(model.calls, [])
        self.assertEqual(len(client.rows("scenes", story_id=story_id)), 1)
        self.assertEqual(len(client.rows("story_characters", story_id=story_id)), 3)

    async def test_a_deleted_story_stops_the_run_without_recording_a_failure(self):
        client = FakeClient()
        story_id = new_story(client)
        model = FakeModel()
        original = model.complete_json

        async def delete_then_answer(system, user, llm_model):
            client.tables["story_plans"] = []  # ON DELETE CASCADE from stories
            client.tables["stories"] = []
            return await original(system, user, llm_model)

        model.complete_json = delete_then_answer
        await run_generation(story_id, planner_for(model), client)
        self.assertEqual(model.kinds(), ["world"])
        self.assertEqual(client.tables.get("characters", []), [])


class LeaseTest(unittest.TestCase):
    def setUp(self):
        self.client = FakeClient()
        self.story_id = new_story(self.client)

    def test_only_one_run_can_claim_a_job(self):
        self.assertIsNotNone(claim_generation(self.client, self.story_id, "run-a"))
        self.assertIsNone(claim_generation(self.client, self.story_id, "run-b"))

    def test_taking_over_an_expired_lease_is_a_compare_and_set(self):
        from unittest.mock import patch

        claim_generation(self.client, self.story_id, "run-a")
        expire_lease(self.client, self.story_id)
        stale_read = dict(self.client.plan(self.story_id))  # run-b and run-c both read this: expired, owned by run-a
        self.assertIsNotNone(claim_generation(self.client, self.story_id, "run-b"))
        with patch.object(generation, "fetch_plan", return_value=stale_read):
            self.assertIsNone(claim_generation(self.client, self.story_id, "run-c"))  # run-a is no longer the owner
        self.assertEqual(self.client.plan(self.story_id)["lease_owner"], "run-b")

    def test_two_runs_racing_for_a_new_job_cannot_both_win(self):
        from unittest.mock import patch

        fresh_read = dict(self.client.plan(self.story_id))  # queued, no owner
        self.assertIsNotNone(claim_generation(self.client, self.story_id, "run-a"))
        with patch.object(generation, "fetch_plan", return_value=fresh_read):
            self.assertIsNone(claim_generation(self.client, self.story_id, "run-b"))
        self.assertEqual(self.client.plan(self.story_id)["lease_owner"], "run-a")

    def test_a_run_that_lost_its_lease_cannot_save(self):
        claim_generation(self.client, self.story_id, "run-a")
        self.client.plan(self.story_id)["lease_owner"] = "run-b"
        job = Job(self.client, self.story_id, "run-a", planner_for(FakeModel()))
        with self.assertRaises(LeaseLost):
            job.save({"step": "world"})

    def test_finished_and_failed_jobs_are_never_claimed(self):
        for status in ("ready", "failed"):
            self.client.plan(self.story_id).update({"status": status, "lease_until": None})
            self.assertIsNone(claim_generation(self.client, self.story_id, "run-a"))
            self.assertFalse(is_stalled(self.client.plan(self.story_id)))


class CreateTest(unittest.TestCase):
    def test_a_story_starts_generating_with_its_seed(self):
        client = FakeClient()
        story, created = create_skeleton_story(client, story_request(), "user-1")
        self.assertTrue(created)
        self.assertEqual((story["status"], story["mode"], story["title"]), ("generating", "skeleton", "새 이야기"))
        plan = client.plan(story["id"])
        self.assertEqual((plan["status"], plan["step"], plan["request_id"]), ("queued", "none", "req-1"))
        self.assertEqual(plan["seed"]["protagonist_name"], "카엘")

    def test_the_same_request_id_returns_the_same_story(self):
        client = FakeClient()
        first, _ = create_skeleton_story(client, story_request(), "user-1")
        second, created = create_skeleton_story(client, story_request(), "user-1")
        self.assertEqual((second["id"], created), (first["id"], False))
        self.assertEqual(len(client.tables["stories"]), 1)

    def test_another_users_request_id_is_rejected(self):
        client = FakeClient()
        create_skeleton_story(client, story_request(), "user-1")
        with self.assertRaises(RequestIdConflict):
            create_skeleton_story(client, story_request(), "user-2")

    def test_at_most_two_stories_generate_at_once(self):
        client = FakeClient()
        create_skeleton_story(client, story_request(request_id="a"), "user-1")
        create_skeleton_story(client, story_request(request_id="b"), "user-1")
        with self.assertRaises(GenerationLimitReached):
            create_skeleton_story(client, story_request(request_id="c"), "user-1")
        create_skeleton_story(client, story_request(request_id="d"), "user-2")  # another user is not limited

    def test_english_requests_get_an_english_placeholder_title(self):
        client = FakeClient()
        story, _ = create_skeleton_story(client, story_request(language="en_US"), "user-1")
        self.assertEqual(story["title"], "New story")


class ParsingTest(unittest.TestCase):
    def test_timestamps_from_the_database_are_parsed_on_python_3_10(self):
        expected = datetime(2026, 11, 10, 7, 21, 25, 120000, tzinfo=timezone.utc)
        self.assertEqual(parse_timestamp("2026-11-10T07:21:25.12+00:00"), expected)
        self.assertEqual(parse_timestamp("2026-11-10T07:21:25.12Z"), expected)
        self.assertEqual(parse_timestamp("2026-11-10T07:21:25+00:00"), expected.replace(microsecond=0))
        self.assertIsNone(parse_timestamp(None))

    def test_model_json_is_read_through_code_fences(self):
        self.assertEqual(parse_json_object('```json\n{"a": 1}\n```'), {"a": 1})
        with self.assertRaises(PlanFormatError):
            parse_json_object("no json here")
        with self.assertRaises(PlanFormatError):
            parse_json_object("{broken")

    def test_the_feature_flag_is_off_by_default(self):
        import os
        from unittest.mock import patch

        with patch.dict(os.environ, {}, clear=True):
            self.assertFalse(generation.is_skeleton_mode_enabled())
        with patch.dict(os.environ, {"SKELETON_MODE_ENABLED": "1"}):
            self.assertTrue(generation.is_skeleton_mode_enabled())



class WaitTimeTest(unittest.IsolatedAsyncioTestCase):
    async def test_the_first_segment_and_the_opening_scene_are_generated_at_the_same_time(self):
        client, model = FakeClient(), FakeModel()
        scene_started = asyncio.Event()
        plan_json, write_text = model.complete_json, model.complete_text

        async def segment_waits_for_scene(system, user, llm_model):
            if model.kind_of(system) == "segment":
                await asyncio.wait_for(scene_started.wait(), timeout=2)  # deadlocks if the two run one after the other
            return await plan_json(system, user, llm_model)

        async def scene_signals(system, user, llm_model):
            scene_started.set()
            return await write_text(system, user, llm_model)

        model.complete_json, model.complete_text = segment_waits_for_scene, scene_signals
        story_id = new_story(client)
        await run_generation(story_id, planner_for(model), client)
        self.assertEqual(client.plan(story_id)["status"], "ready")
        self.assertEqual(len(client.rows("scenes", story_id=story_id)), 1)

    async def test_a_failed_segment_cancels_the_opening_draft_and_nothing_is_saved_half_way(self):
        client = FakeClient()
        model = FakeModel(segments=(SEGMENT_STUCK,))
        story_id = new_story(client)
        await run_generation(story_id, planner_for(model), client)
        self.assertEqual(client.plan(story_id)["status"], "failed")
        self.assertEqual(client.rows("scenes", story_id=story_id), [])

    async def test_why_steps_were_asked_again_is_recorded(self):
        client, model = FakeClient(), FakeModel(spines=(SPINE_WITH_PROBLEM,), segments=(SEGMENT_STUCK, SEGMENT))
        story_id = new_story(client)
        await run_generation(story_id, planner_for(model), client)
        log = client.plan(story_id)["retry_log"]
        self.assertEqual([entry["step"] for entry in log], ["spine", "segment"])
        self.assertIn("e04: 원인(because)이 없다", log[0]["problems"])
        self.assertTrue(any("구간이 끝나도 갖춰지지 않는다" in problem for problem in log[1]["problems"]))

    async def test_failed_attempts_are_recorded_with_their_error(self):
        client = FakeClient()
        outage = ExternalServiceError("OpenRouter story scene", "일시적인 서버 문제가 발생했습니다.", "503")
        story_id = new_story(client)
        await run_generation(story_id, planner_for(FakeModel(fail_on={"scene": outage})), client)
        errors = [entry for entry in client.plan(story_id)["retry_log"] if "error" in entry]
        self.assertEqual(len(errors), 3)
        self.assertEqual(errors[0]["step"], "after:segment")  # the segment was saved; only the scene is retried
        self.assertIn("ExternalServiceError", errors[0]["error"])

if __name__ == "__main__":
    unittest.main()
