import copy
import unittest

from app.services.story_state import (
    EventRejected,
    StateChange,
    apply_event,
    build_initial_state,
    diff_states,
    introduce_entities,
)


def sample_world():
    return {
        "locations": ["왕성", "숲", "항구"],
        "characters": {
            "카엘": {"at": "왕성", "role": "protagonist"},
            "세라": {"at": "왕성", "role": "antagonist"},
            "도윤": {"at": "숲", "role": "ally"},
        },
        "items": {"은빛 단검": {"holder": "도윤"}},
        "relations": [["카엘", "세라", "ally"], ["카엘", "도윤", "ally"]],
    }


def apply_all(state, events, origin="scene"):
    for event in events:
        state = apply_event(state, event, origin)
    return state


class InitialStateTest(unittest.TestCase):
    def test_world_definition_becomes_state(self):
        state = build_initial_state(sample_world())
        self.assertEqual(state["chars"]["도윤"], {"alive": True, "at": "숲"})
        self.assertEqual(state["items"], {"은빛 단검": "도윤"})
        self.assertEqual(state["rels"], {"세라·카엘": "ally", "도윤·카엘": "ally"})
        self.assertEqual(state["facts"], {})


class ApplyEventTest(unittest.TestCase):
    def setUp(self):
        self.state = build_initial_state(sample_world())

    def assert_rejected(self, event, reason, state=None):
        with self.assertRaises(EventRejected) as caught:
            apply_event(state or self.state, event)
        self.assertIn(reason, str(caught.exception))

    def test_move_give_and_relate_change_the_state(self):
        state = apply_all(self.state, [
            {"type": "move", "who": "카엘", "to": "숲"},
            {"type": "give", "who": "도윤", "to": "카엘", "item": "은빛 단검"},
            {"type": "relate", "a": "세라", "b": "카엘", "kind": "enemy"},
        ])
        self.assertEqual(state["chars"]["카엘"]["at"], "숲")
        self.assertEqual(state["items"]["은빛 단검"], "카엘")
        self.assertEqual(state["rels"]["세라·카엘"], "enemy")

    def test_input_state_is_never_mutated(self):
        before = copy.deepcopy(self.state)
        apply_event(self.state, {"type": "die", "who": "도윤"})
        with self.assertRaises(EventRejected):
            apply_event(self.state, {"type": "give", "who": "카엘", "to": "세라", "item": "은빛 단검"})
        self.assertEqual(self.state, before)

    def test_dead_character_cannot_act_move_or_die_again(self):
        dead = apply_event(self.state, {"type": "die", "who": "도윤"})
        self.assert_rejected({"type": "act", "who": "도윤"}, "이미 죽었다", dead)
        self.assert_rejected({"type": "move", "who": "도윤", "to": "왕성"}, "이미 죽었다", dead)
        self.assert_rejected({"type": "die", "who": "도윤"}, "이미 죽었다", dead)
        self.assert_rejected({"type": "mark", "who": "도윤", "fact": "도윤이 비밀을 털어놓았다"}, "이미 죽었다", dead)

    def test_preconditions_are_checked(self):
        self.assert_rejected({"type": "act", "who": "카엘", "with": "도윤"}, "같은 장소에 없다")
        self.assert_rejected({"type": "give", "who": "카엘", "to": "세라", "item": "은빛 단검"}, "갖고 있지 않다")
        self.assert_rejected({"type": "move", "who": "카엘", "to": "달"}, "정의되지 않은 장소")
        self.assert_rejected({"type": "relate", "a": "카엘", "b": "세라", "kind": "rival"}, "정의되지 않은 관계")
        self.assert_rejected({"type": "act", "who": "하린"}, "등장인물이 아니다")
        self.assert_rejected({"type": "revive", "who": "도윤"}, "정의되지 않은 사건 종류")
        self.assert_rejected({"type": "move", "who": "카엘"}, "필요한 값이 없다")

    def test_unknown_origin_is_a_programming_error(self):
        with self.assertRaises(ValueError):
            apply_event(self.state, {"type": "act", "who": "카엘"}, origin="model")


class FactTest(unittest.TestCase):
    def setUp(self):
        self.state = build_initial_state(sample_world())

    def test_mark_establishes_a_fact_with_its_people_and_origin(self):
        state = apply_event(
            self.state, {"type": "mark", "who": "카엘", "with": "세라", "fact": "카엘이  세라를\n용서하지 않기로 했다"}, "choice"
        )
        self.assertEqual(state["facts"], {"카엘이 세라를 용서하지 않기로 했다": {"people": ["카엘", "세라"], "origin": "choice"}})

    def test_an_established_fact_keeps_its_first_record(self):
        state = apply_event(self.state, {"type": "mark", "who": "카엘", "fact": "약속"}, "choice")
        state = apply_event(state, {"type": "mark", "who": "세라", "fact": "약속"}, "scene")
        self.assertEqual(state["facts"]["약속"], {"people": ["카엘"], "origin": "choice"})

    def test_a_fact_needs_a_name(self):
        with self.assertRaises(EventRejected):
            apply_event(self.state, {"type": "mark", "who": "카엘", "fact": "  "})


class IntroduceEntitiesTest(unittest.TestCase):
    def setUp(self):
        self.state = build_initial_state(sample_world())

    def test_new_location_character_and_item_are_registered_in_order(self):
        state = introduce_entities(
            self.state,
            locations=["등대"],
            characters=[{"name": "하린", "at": "등대"}],
            items=[{"name": "낡은 지도", "holder": "하린"}],
        )
        self.assertIn("등대", state["locations"])
        self.assertEqual(state["chars"]["하린"], {"alive": True, "at": "등대"})
        self.assertEqual(state["items"]["낡은 지도"], "하린")
        apply_event(state, {"type": "give", "who": "하린", "to": "하린", "item": "낡은 지도"})

    def test_existing_names_are_ignored(self):
        state = introduce_entities(self.state, characters=[{"name": "도윤", "at": "항구"}])
        self.assertEqual(state["chars"]["도윤"]["at"], "숲")

    def test_new_character_must_start_at_a_known_location(self):
        with self.assertRaises(EventRejected):
            introduce_entities(self.state, characters=[{"name": "하린", "at": "사막"}])

    def test_new_item_needs_a_living_holder(self):
        dead = apply_event(self.state, {"type": "die", "who": "도윤"})
        with self.assertRaises(EventRejected):
            introduce_entities(dead, items=[{"name": "낡은 지도", "holder": "도윤"}])


class DiffStatesTest(unittest.TestCase):
    def test_only_changed_cells_are_listed(self):
        before = build_initial_state(sample_world())
        self.assertEqual(diff_states(before, before), [])
        after = apply_all(before, [
            {"type": "die", "who": "도윤"},
            {"type": "mark", "who": "카엘", "fact": "카엘이 복수를 맹세했다"},
        ])
        self.assertEqual(diff_states(before, after), [
            StateChange("도윤", "alive", "alive", "dead"),
            StateChange("카엘이 복수를 맹세했다", "fact", None, "established"),
        ])


if __name__ == "__main__":
    unittest.main()
