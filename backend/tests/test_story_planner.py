import unittest

from app.services.story_planner import (
    PlanFormatError,
    find_world_problems,
    plan_segment,
    plan_spine,
    plan_world,
    scene_length,
)
from app.services.story_skeleton import walk_spine
from app.services.story_state import build_initial_state
from story_fakes import SEGMENT, SPINE, WORLD, FakeModel, change, choices, promise, tone

NO_TRACE = ("no choice leaves a trace (a new fact, a move, a hand-over or a relation change); "
            "establishing a fact that already holds changes nothing")

SEED = {"genre": "fantasy", "tone": "진지하고 무거운", "protagonist_name": "카엘", "language": "ko-KR",
        "opening_scenario": "폭풍이 치는 밤에 시작한다"}


async def planned_world(model=None):
    model = model or FakeModel()
    world, problems = await plan_world(SEED, "fast", model.complete_json)
    _, facts, events = await plan_spine(world, SEED, "pro", model.complete_json)
    return {**world, "facts": facts, "spine": events}, problems


class WorldTest(unittest.IsolatedAsyncioTestCase):
    async def test_world_is_parsed_into_the_engine_shape(self):
        model = FakeModel()
        world, problems = await plan_world(SEED, "fast", model.complete_json)
        self.assertEqual(problems, [])
        self.assertEqual(world["viewpoint"], "카엘")
        self.assertEqual(world["characters"]["도윤"]["at"], "숲")
        self.assertEqual(world["items"], {"은빛 단검": {"holder": "도윤"}})
        self.assertEqual(world["relations"][0], ["카엘", "세라", "ally"])
        self.assertIn("폭풍이 치는 밤에 시작한다", model.calls[0][2])

    async def test_the_model_is_told_the_output_language(self):
        model = FakeModel()
        captured = {}
        original = model.complete_json

        async def capture(system, user, llm_model):
            captured["system"] = system
            return await original(system, user, llm_model)

        await plan_world({**SEED, "language": "en_US"}, "fast", capture)
        self.assertIn("in en_US", captured["system"])

    async def test_ensemble_stories_have_no_viewpoint(self):
        world, _ = await plan_world({**SEED, "narrative_type": "ensemble"}, "fast", FakeModel().complete_json)
        self.assertIsNone(world["viewpoint"])

    async def test_names_and_kinds_that_do_not_resolve_are_problems(self):
        broken = {**WORLD,
                  "characters": WORLD["characters"] + [{"name": "카엘", "role": "ally", "wants": "", "voice": "", "at": "사막"}],
                  "relations": [{"a": "카엘", "b": "하린", "kind": "rival"}]}
        _, problems = await plan_world(SEED, "fast", FakeModel(world=broken).complete_json)
        self.assertIn("character names are not unique", problems)
        self.assertIn("relation names '하린', who is not a character", problems)
        self.assertTrue(any("rival" in problem for problem in problems))

    async def test_a_missing_list_is_a_format_error(self):
        with self.assertRaises(PlanFormatError):
            await plan_world(SEED, "fast", FakeModel(world={"title": "x"}).complete_json)

    def test_the_requested_protagonist_must_keep_the_role(self):
        world = {"characters": {"카엘": {"role": "ally", "at": "숲"}, "세라": {"role": "protagonist", "at": "숲"}},
                 "locations": ["숲"], "items": {}, "relations": []}
        self.assertIn("the protagonist must be '카엘'", find_world_problems(world, SEED, 2))


class SpineTest(unittest.IsolatedAsyncioTestCase):
    async def test_events_written_ending_first_come_back_in_time_order(self):
        world, _ = await planned_world()
        self.assertEqual([event["id"] for event in world["spine"]], ["e01", "e02", "e03", "e04", "e05"])
        self.assertEqual(world["facts"], SPINE["facts"])

    async def test_changes_and_needs_become_engine_events(self):
        world, _ = await planned_world()
        e04, e05 = world["spine"][3], world["spine"][4]
        self.assertEqual(e04["events"][0], {"type": "mark", "who": "세라", "with": "카엘", "fact": SPINE["facts"][0]})
        self.assertEqual(e05["needs"], [["at", "세라", "항구"], ["has", "카엘", "은빛 단검"], ["fact", SPINE["facts"][0]]])

    async def test_a_change_written_with_the_needs_key_is_accepted(self):
        mistaken = {**SPINE["events"][-1], "changes": [{"pred": "act", "a": "카엘", "b": "세라", "item": None, "kind": None, "fact": None}]}
        model = FakeModel(spines=({**SPINE, "events": [mistaken]},))
        world, _ = await plan_world(SEED, "fast", model.complete_json)
        _, _, events = await plan_spine(world, SEED, "pro", model.complete_json)
        self.assertEqual(events[0]["events"], [{"type": "act", "who": "카엘", "with": "세라"}])

    async def test_a_place_in_the_partner_field_of_act_means_no_partner(self):
        spine = {**SPINE, "events": [{**SPINE["events"][-1], "changes": [change("act", "카엘", "왕성")]}]}
        model = FakeModel(spines=(spine,))
        world, _ = await plan_world(SEED, "fast", model.complete_json)
        _, _, events = await plan_spine(world, SEED, "pro", model.complete_json)
        self.assertEqual(events[0]["events"], [{"type": "act", "who": "카엘"}])


class SegmentTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.world, _ = await planned_world()
        _, self.state = walk_spine(build_initial_state(self.world), self.world["spine"][:1], self.world["facts"])

    async def plan(self, segment):
        return await plan_segment(self.world, SEED, self.state, 1, "fast", FakeModel(segments=(segment,)).complete_json)

    async def test_a_good_segment_has_no_problems(self):
        cards, after_event, problems = await self.plan(SEGMENT)
        self.assertEqual(problems, [])
        self.assertEqual([card["id"] for card in cards], ["s1", "s2"])
        self.assertEqual(cards[0]["fixed"], [{"type": "move", "who": "카엘", "to": "숲"}])
        self.assertEqual(len(after_event), 4)

    async def test_choice_kind_comes_from_the_effect(self):
        talk = {"label": "말을 건다", "kind": "action", "changes": [change("act", "카엘")]}
        segment = {**SEGMENT, "scenes": [{**SEGMENT["scenes"][0], "choices": [tone("a"), talk]}] + SEGMENT["scenes"][1:]}
        cards, _, _ = await self.plan(segment)
        self.assertEqual([choice["kind"] for choice in cards[0]["choices"]], ["tone", "tone"])

    async def test_scenes_without_lasting_or_quiet_choices_are_problems(self):
        quiet_only = [tone("a"), tone("b"), tone("c")]
        lasting_only = [promise("a", "약속 a"), promise("b", "약속 b"), promise("c", "약속 c")]
        segment = {"after_event_choices": quiet_only,
                   "scenes": [{**SEGMENT["scenes"][0], "choices": lasting_only}, {**SEGMENT["scenes"][1], "choices": choices("x")[:2]}]}
        _, _, problems = await self.plan(segment)
        self.assertIn(("e01", NO_TRACE), problems)
        self.assertIn(("s1", "no choice is only about attitude (empty changes)"), problems)
        self.assertIn(("s2", "only 2 choices can be offered (3 or more needed)"), problems)

    async def test_re_establishing_a_fact_that_already_holds_is_not_a_trace(self):
        already = [tone("a"), tone("b"), promise("c", "같은 약속"), promise("d", "같은 약속")]
        state = {**self.state, "facts": {**self.state["facts"], "같은 약속": {"people": ["카엘"], "origin": "choice"}}}
        _, _, problems = await plan_segment(self.world, SEED, state, 1, "fast",
                                            FakeModel(segments=({**SEGMENT, "after_event_choices": already},)).complete_json)
        self.assertIn(("e01", NO_TRACE), problems)

    async def test_a_segment_that_does_not_arrive_reports_the_missing_condition(self):
        stuck = {**SEGMENT, "scenes": [{**SEGMENT["scenes"][0], "changes": [change("act", "카엘")]}]}
        _, _, problems = await self.plan(stuck)
        self.assertIn(("e02", "still unmet when the segment ends: 도윤 and 카엘 are in the same place"), problems)

    async def test_later_events_are_listed_as_not_yet(self):
        model = FakeModel()
        await plan_segment(self.world, SEED, self.state, 1, "fast", model.complete_json)
        user = model.calls[-1][2]
        self.assertIn("Not yet (do not bring these forward):", user)
        self.assertIn("- e03", user)
        self.assertIn("Tasks to solve:\n- 도윤 and 카엘 are in the same place", user)


class SceneLengthTest(unittest.TestCase):
    def test_turning_points_are_longer_than_transitions(self):
        self.assertLess(scene_length(1), scene_length(5))
        self.assertEqual(scene_length(None), scene_length(3))

    def test_the_opening_is_long_whatever_its_intensity(self):
        self.assertEqual(scene_length(1, is_opening=True), 3000)


if __name__ == "__main__":
    unittest.main()
