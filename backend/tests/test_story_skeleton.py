import copy
import unittest

from app.services.story_skeleton import (
    build_brief,
    check_craft,
    check_segment,
    check_spine,
    choice_changes_state,
    forget_scene_facts,
    offer_choices,
    segment_task,
    walk_cards,
    walk_spine,
)
from app.services.story_state import apply_event, build_initial_state

BETRAYAL_REVEALED = "세라가 매복을 알린 사실이 드러났다"


def sample_world():
    """Five major events and the segment between the first two."""
    return {
        "viewpoint": "카엘",
        "locations": ["왕성", "숲", "항구"],
        "characters": {
            "카엘": {"at": "왕성", "role": "protagonist"},
            "세라": {"at": "왕성", "role": "antagonist"},
            "도윤": {"at": "숲", "role": "ally"},
        },
        "items": {"은빛 단검": {"holder": "도윤"}},
        "relations": [["카엘", "세라", "ally"], ["카엘", "도윤", "ally"]],
        "facts": [BETRAYAL_REVEALED],
        "spine": [
            {"id": "e01", "when": 1, "title": "출정 전야", "intensity": 1, "dilemma": "캐물을지 넘어갈지",
             "events": [{"type": "act", "who": "카엘", "with": "세라"}], "because": [], "plants": ["세라의 망설임"]},
            {"id": "e02", "when": 3, "title": "맡겨진 단검", "intensity": 2,
             "events": [{"type": "give", "who": "도윤", "to": "카엘", "item": "은빛 단검"}], "because": ["e01"],
             "plants": ["단검의 내력"]},
            {"id": "e03", "when": 3, "title": "매복", "intensity": 4, "cost": "스승을 잃는다",
             "events": [{"type": "die", "who": "도윤"}], "because": ["e02"]},
            {"id": "e04", "when": 10, "title": "배신", "intensity": 3, "dilemma": "붙잡을지 보낼지", "cost": "동맹이 끝난다",
             "needs": [["together", "세라", "카엘"]],
             "events": [{"type": "mark", "who": "세라", "with": "카엘", "fact": BETRAYAL_REVEALED},
                        {"type": "relate", "a": "세라", "b": "카엘", "kind": "enemy"}],
             "because": ["e01", "e03"], "pays": ["세라의 망설임"]},
            {"id": "e05", "when": 12, "title": "대면", "intensity": 5, "dilemma": "복수할지 받아들일지", "cost": "돌아갈 수 없다",
             "needs": [["at", "세라", "항구"], ["has", "카엘", "은빛 단검"], ["fact", BETRAYAL_REVEALED]],
             "events": [{"type": "act", "who": "카엘", "with": "세라"}], "because": ["e04"], "pays": ["단검의 내력"]},
        ],
        "segment": [
            {"id": "s1", "title": "길을 나서다", "fixed": [{"type": "move", "who": "카엘", "to": "숲"}], "choices": [
                {"id": "c1", "label": "말없이 걷는다", "events": []},
                {"id": "c2", "label": "세라와 함께 간다", "events": [{"type": "move", "who": "세라", "to": "숲"}]},
                {"id": "c3", "label": "도윤을 왕성으로 부른다", "events": [{"type": "move", "who": "도윤", "to": "왕성"}]},
                {"id": "c4", "label": "세라를 벤다", "events": [{"type": "die", "who": "세라"}]},
                {"id": "c5", "label": "세라에게 단검을 건넨다",
                 "events": [{"type": "give", "who": "카엘", "to": "세라", "item": "은빛 단검"}]},
                {"id": "c6", "label": "주변을 살핀다", "events": [{"type": "act", "who": "카엘"}]},
                {"id": "c7", "label": "세라에게 말을 건다", "events": [{"type": "act", "who": "카엘", "with": "세라"}]},
            ]},
            {"id": "s2", "title": "숲의 오두막", "fixed": [{"type": "act", "who": "카엘", "with": "도윤"}]},
        ],
    }


def event_by_id(world, event_id):
    return next(spine_event for spine_event in world["spine"] if spine_event["id"] == event_id)


def state_after_first_event(world):
    _, state = walk_spine(build_initial_state(world), world["spine"][:1], world["facts"])
    return state


def mark(state, origin, who, fact):
    return apply_event(state, {"type": "mark", "who": who, "fact": fact}, origin)


SCENE_CARD = {"id": "x", "title": "카엘의 장면", "fixed": [{"type": "act", "who": "카엘"}]}


class SpineTest(unittest.TestCase):
    def setUp(self):
        self.world = sample_world()

    def test_sample_spine_holds_and_returns_gaps_as_segment_tasks(self):
        report = check_spine(self.world)
        self.assertEqual(report.errors, [])
        self.assertEqual(report.warnings, [])
        gaps = {result.id: result.gaps for result in report.events}
        self.assertEqual(gaps["e02"], [("together", "도윤", "카엘")])  # added by code from the give event
        self.assertEqual(gaps["e05"], [("at", "세라", "항구"), ("together", "카엘", "세라")])

    def test_a_dead_character_is_an_error_not_a_gap(self):
        event_by_id(self.world, "e05")["needs"].append(["alive", "도윤"])
        self.assertIn(("e05", "도윤 은(는) 이미 죽었다 — 필요한 조건: 도윤 이(가) 살아 있다"), check_spine(self.world).errors)

    def test_an_item_held_by_the_dead_cannot_be_handed_over(self):
        event_by_id(self.world, "e02")["events"] = [{"type": "act", "who": "카엘", "with": "도윤"}]
        errors = check_spine(self.world).errors
        self.assertIn(("e05", "은빛 단검 을(를) 가진 도윤 이(가) 이미 죽었다 — 필요한 조건: 카엘 이(가) 은빛 단검 을(를) 갖고 있다"), errors)

    def test_order_cause_and_ids_are_checked(self):
        event_by_id(self.world, "e03")["because"] = []
        event_by_id(self.world, "e02")["because"] = ["e04"]
        event_by_id(self.world, "e04")["when"] = 2
        event_by_id(self.world, "e05")["id"] = "e04"
        errors = check_spine(self.world).errors
        self.assertIn(("e03", "원인(because)이 없다"), errors)
        self.assertIn(("e02", "원인 'e04' 이(가) 앞선 사건이 아니다"), errors)
        self.assertIn(("e04", "시간이 거꾸로 간다(3일 → 2일)"), errors)
        self.assertIn(("e04", "사건 ID 가 겹친다"), errors)

    def test_fact_names_must_be_on_the_spine_list(self):
        event_by_id(self.world, "e05")["needs"].append(["fact", "세라의 배신이 드러남"])
        event_by_id(self.world, "e03")["events"].append({"type": "mark", "who": "카엘", "fact": "카엘이 복수를 맹세했다"})
        errors = check_spine(self.world).errors
        self.assertIn(("e05", "'세라의 배신이 드러남' 은(는) 정의되지 않은 사실이다"), errors)
        self.assertIn(("e03", "'카엘이 복수를 맹세했다' 은(는) 정의되지 않은 사실이다"), errors)

    def test_an_unset_fact_becomes_a_gap(self):
        event_by_id(self.world, "e04")["events"] = [{"type": "relate", "a": "세라", "b": "카엘", "kind": "enemy"}]
        report = check_spine(self.world)
        self.assertEqual(report.errors, [])
        self.assertIn(("fact", BETRAYAL_REVEALED), {result.id: result.gaps for result in report.events}["e05"])

    def test_hooks_and_absent_characters_are_reported(self):
        self.world["spine"][0]["plants"] = ["왕의 밀명"]
        self.world["characters"]["하린"] = {"at": "항구"}
        report = check_spine(self.world)
        self.assertIn(("e04", "심지 않은 복선을 회수한다: 세라의 망설임"), report.errors)
        self.assertTrue(any("왕의 밀명" in warning for warning in report.warnings))
        self.assertIn("하린 이(가) 어느 주요 사건에도 나오지 않는다", report.warnings)

    def test_segment_task_lists_gaps_and_days(self):
        self.assertEqual(segment_task(self.world, 3), {"gaps": [("together", "세라", "카엘")], "days": 7, "reintroduce": []})

    def test_walk_spine_does_not_mutate_its_input(self):
        state = build_initial_state(self.world)
        before = copy.deepcopy(state)
        walk_spine(state, self.world["spine"], self.world["facts"])
        self.assertEqual(state, before)


class SegmentTest(unittest.TestCase):
    def setUp(self):
        self.world = sample_world()
        self.state = state_after_first_event(self.world)

    def test_sample_segment_arrives_at_the_next_major_event(self):
        self.assertEqual(check_segment(self.state, self.world["segment"], self.world["spine"][1], self.world["facts"]), ([], []))

    def test_unmet_needs_are_returned(self):
        cards = [{"id": "s1", "fixed": [{"type": "act", "who": "카엘"}]}]
        errors, unmet = check_segment(self.state, cards, self.world["spine"][1], self.world["facts"])
        self.assertEqual((errors, unmet), ([], [("together", "도윤", "카엘")]))

    def test_a_card_that_does_not_hold_is_reported(self):
        cards = [{"id": "s1", "fixed": [{"type": "act", "who": "카엘", "with": "도윤"}]}]
        errors, _ = check_segment(self.state, cards, self.world["spine"][1], self.world["facts"])
        self.assertEqual(errors[0][0], "s1")
        self.assertIn("같은 장소에 없다", errors[0][1])

    def test_a_used_item_must_be_held_by_someone_in_the_scene(self):
        results, _ = walk_cards(self.state, [{"id": "s1", "fixed": [{"type": "act", "who": "카엘"}], "uses": ["은빛 단검"]}])
        self.assertEqual(results[0].errors, ["이 장면의 인물 가운데 '은빛 단검' 을(를) 가진 사람이 없다(소지자: 도윤)"])


class ChoiceTest(unittest.TestCase):
    def setUp(self):
        self.world = sample_world()
        cards = self.world["segment"]
        _, self.state = walk_cards(state_after_first_event(self.world), cards[:1], self.world["facts"])

    def offered(self, wanted=6):
        cards = self.world["segment"]
        choices = offer_choices(self.state, cards[0], cards[1:], self.world["spine"][1:], self.world["facts"], wanted)
        return {choice["id"]: choice for choice in choices}

    def test_impossible_and_spine_breaking_choices_are_not_offered(self):
        offered = self.offered()
        self.assertNotIn("c4", offered)  # killing 세라 makes the later betrayal impossible
        self.assertNotIn("c5", offered)  # 카엘 does not hold the dagger yet
        self.assertNotIn("c7", offered)  # 카엘 is in the forest, 세라 is still at the castle
        self.assertEqual(set(offered), {"c1", "c2", "c3", "c6"})

    def test_choices_that_break_the_rest_of_the_segment_need_a_replan(self):
        offered = self.offered()
        self.assertTrue(offered["c3"]["replan"])  # 도윤 leaves the forest, so the cabin scene fails
        self.assertFalse(offered["c2"]["replan"])

    def test_three_are_picked_for_variety_in_the_cards_order(self):
        cards = self.world["segment"]
        choices = offer_choices(self.state, cards[0], cards[1:], self.world["spine"][1:], self.world["facts"])
        # c1: attitude, c2: a move that lasts, then c6 (does something new: acts) over c3 (another move)
        self.assertEqual([choice["id"] for choice in choices], ["c1", "c2", "c6"])

    def test_talking_alone_does_not_count_as_changing_state(self):
        self.assertFalse(choice_changes_state({"events": [{"type": "act", "who": "카엘", "with": "세라"}]}))
        self.assertTrue(choice_changes_state({"events": [{"type": "mark", "who": "카엘", "fact": "약속"}]}))


class BriefTest(unittest.TestCase):
    def setUp(self):
        self.world = sample_world()
        self.state = build_initial_state(self.world)

    def test_brief_holds_only_what_the_scene_reads(self):
        _, end = walk_spine(self.state, self.world["spine"][:4], self.world["facts"])
        end = apply_event(end, {"type": "move", "who": "세라", "to": "항구"})
        brief = build_brief({"id": "b", "title": "추격", "fixed": [{"type": "move", "who": "카엘", "to": "항구"}]}, end)
        self.assertNotIn("같은 장소", brief)  # 세라 already left for the harbour
        self.assertNotIn("단검", brief)  # the dagger plays no part in this scene
        self.assertNotIn("관계:", brief)
        self.assertIn("사실: " + BETRAYAL_REVEALED, brief)  # the betrayal involves 카엘, so it travels with him

    def test_bystanders_relations_and_items_are_included(self):
        _, end = walk_spine(self.state, self.world["spine"][:2], self.world["facts"])
        card = {"id": "b", "title": "숲", "fixed": [{"type": "act", "who": "카엘", "with": "도윤"}], "uses": ["은빛 단검"]}
        brief = build_brief(card, end)
        self.assertIn("인물: 카엘(숲), 도윤(숲)", brief)
        self.assertIn("물건: 은빛 단검 — 카엘", brief)
        self.assertIn("관계: 도윤·카엘 동맹", brief)

    def test_facts_are_ordered_by_tier_and_labelled(self):
        state = mark(self.state, "scene", "카엘", "카엘이 말에게 물을 먹였다")
        state = mark(state, "choice", "카엘", "카엘이 돌아오겠다고 약속했다")
        state = mark(state, "scene", "세라", BETRAYAL_REVEALED)  # on the spine list, so core whoever set it
        brief = build_brief(SCENE_CARD, state, self.world["facts"])
        fact_lines = [line for line in brief.split("\n") if line.startswith(("사실", "독자의 선택", "최근의 일"))]
        self.assertEqual(fact_lines, [
            "사실: " + BETRAYAL_REVEALED,  # tied to 세라, who is at the same place as 카엘
            "독자의 선택: 카엘이 돌아오겠다고 약속했다",
            "최근의 일: 카엘이 말에게 물을 먹였다",
        ])
        away = apply_event(state, {"type": "move", "who": "세라", "to": "항구"})
        self.assertNotIn(BETRAYAL_REVEALED, build_brief(SCENE_CARD, away, self.world["facts"]))

    def test_minor_facts_cannot_push_out_important_ones(self):
        state = mark(self.state, "spine", "카엘", "핵심 사실")
        state = mark(state, "choice", "카엘", "카엘이 돌아오겠다고 약속했다")
        for index in range(20):
            state = mark(state, "scene", "카엘", f"사소한 일 {index}")
        brief = build_brief(SCENE_CARD, state, self.world["facts"])
        self.assertIn("사실: 핵심 사실", brief)
        self.assertIn("독자의 선택: 카엘이 돌아오겠다고 약속했다", brief)
        recent = [line for line in brief.split("\n") if line.startswith("최근의 일")]
        self.assertEqual(recent, ["최근의 일: 사소한 일 18", "최근의 일: 사소한 일 19"])

    def test_reader_choices_are_capped_to_the_latest_four(self):
        state = self.state
        for index in range(6):
            state = mark(state, "choice", "카엘", f"선택 {index}")
        choices = [line for line in build_brief(SCENE_CARD, state).split("\n") if line.startswith("독자의 선택")]
        self.assertEqual(choices, [f"독자의 선택: 선택 {index}" for index in range(2, 6)])

    def test_a_needed_fact_is_always_included(self):
        state = mark(self.state, "spine", "세라", BETRAYAL_REVEALED)
        for index in range(10):
            state = mark(state, "spine", "카엘", f"핵심 {index}")
        card = {**SCENE_CARD, "needs": [["fact", BETRAYAL_REVEALED]]}
        brief = build_brief(card, state, self.world["facts"])
        self.assertIn("사실: " + BETRAYAL_REVEALED, brief)
        self.assertEqual(len([line for line in brief.split("\n") if line.startswith("사실:")]), 8)

    def test_scene_facts_are_forgotten_after_a_major_event(self):
        state = mark(self.state, "scene", "카엘", "카엘이 말에게 물을 먹였다")
        state = mark(state, "choice", "카엘", "카엘이 돌아오겠다고 약속했다")
        self.assertEqual(list(forget_scene_facts(state)["facts"]), ["카엘이 돌아오겠다고 약속했다"])
        _, end = walk_spine(state, self.world["spine"][:4], self.world["facts"])
        self.assertEqual(list(end["facts"]), ["카엘이 돌아오겠다고 약속했다", BETRAYAL_REVEALED])
        self.assertIn("카엘이 말에게 물을 먹였다", state["facts"])


class CraftTest(unittest.TestCase):
    def setUp(self):
        self.world = sample_world()

    def problems(self):
        return [reason for _, reason in check_craft(self.world)]

    def test_sample_spine_passes(self):
        self.assertEqual(check_craft(self.world), [])

    def test_an_ending_without_cost_is_flagged(self):
        event_by_id(self.world, "e04")["events"] = [{"type": "act", "who": "세라", "with": "카엘"}]
        self.assertTrue(any("되돌릴 수 없는 대가" in problem for problem in self.problems()))
        event_by_id(self.world, "e05")["events"].append({"type": "give", "who": "카엘", "to": "세라", "item": "은빛 단검"})
        self.assertFalse(any("되돌릴 수 없는 대가" in problem for problem in self.problems()))

    def test_a_passive_protagonist_and_idle_cast_are_flagged(self):
        event_by_id(self.world, "e01")["events"] = [{"type": "act", "who": "세라"}]
        event_by_id(self.world, "e05")["events"] = [{"type": "act", "who": "세라", "with": "카엘"}]
        event_by_id(self.world, "e02")["events"] = [{"type": "act", "who": "카엘", "with": "도윤"}]
        problems = self.problems()
        self.assertIn("주인공이 직접 행동하는 사건이 5개 중 2개뿐이다(절반 이상 필요)", problems)
        self.assertIn("도윤(조력자) 이(가) 어느 사건에서도 직접 행동하지 않는다", problems)

    def test_the_tension_curve_is_checked(self):
        for spine_event, level in zip(self.world["spine"], [1, 2, 3, 4, 5]):
            spine_event["intensity"] = level
        self.assertEqual(self.problems(), ["후반부에 절정을 앞두고 강도가 한 번 꺾이는 사건이 없다"])
        for spine_event, level in zip(self.world["spine"], [5, 4, 3, 3, 3]):
            spine_event["intensity"] = level
        problems = self.problems()
        self.assertIn("강도가 가장 높은 사건(e01)이 마지막 2개 안에 없다", problems)
        self.assertTrue(any("뒤로 갈수록 강도가 오르지 않는다" in problem for problem in problems))

    def test_empty_cost_and_dilemma_point_at_the_event(self):
        event_by_id(self.world, "e03")["cost"] = " "
        event_by_id(self.world, "e05")["dilemma"] = ""
        self.assertEqual(check_craft(self.world), [
            ("e03", "강도 3 이상인 사건인데 대가(cost)가 비어 있다"),
            ("e05", "주인공이 행동하는 사건인데 딜레마(dilemma)가 비어 있다"),
        ])

    def test_ensemble_without_roles_skips_role_checks(self):
        self.world["viewpoint"] = None
        for character in self.world["characters"].values():
            character.pop("role")
        self.assertEqual(check_craft(self.world), [])



class LastingChoiceTest(unittest.TestCase):
    def test_a_choice_is_lasting_only_if_it_changes_the_state_here(self):
        from app.services.story_skeleton import choice_leaves_trace

        state = build_initial_state(sample_world())
        promise = {"events": [{"type": "mark", "who": "카엘", "fact": "약속"}]}
        self.assertTrue(choice_leaves_trace(state, promise))
        self.assertFalse(choice_leaves_trace(mark(state, "choice", "카엘", "약속"), promise))
        self.assertFalse(choice_leaves_trace(state, {"events": [{"type": "act", "who": "카엘"}]}))
        self.assertFalse(choice_leaves_trace(state, {"events": [{"type": "die", "who": "하린"}]}))  # does not hold

    def test_offered_choices_carry_whether_they_last(self):
        world = sample_world()
        state = mark(build_initial_state(world), "choice", "카엘", "약속")
        card = {"id": "x", "choices": [{"id": "old", "events": [{"type": "mark", "who": "카엘", "fact": "약속"}]},
                                      {"id": "new", "events": [{"type": "mark", "who": "카엘", "fact": "새 약속"}]}]}
        offered = {choice["id"]: choice["lasting"] for choice in offer_choices(state, card, [], [], None, 9)}
        self.assertEqual(offered, {"old": False, "new": True})


class OpeningCraftTest(unittest.TestCase):
    def test_a_hero_story_must_open_with_the_protagonist(self):
        world = sample_world()
        event_by_id(world, "e01")["events"] = [{"type": "act", "who": "세라"}]
        self.assertIn(("전체", "첫 사건에서 주인공이 행동하지 않는다(첫 장면은 주인공의 장면이어야 한다)"), check_craft(world))
        world["viewpoint"] = None  # an ensemble story has no protagonist to open with
        self.assertFalse(any("첫 사건" in reason for _, reason in check_craft(world)))


class BriefWordingTest(unittest.TestCase):
    def test_events_are_written_as_sentences(self):
        from app.services.story_skeleton import describe_event

        self.assertEqual(describe_event({"type": "move", "who": "카엘", "to": "숲"}), "카엘 이(가) 숲(으)로 간다")
        self.assertEqual(describe_event({"type": "relate", "a": "세라", "b": "카엘", "kind": "enemy"}),
                         "세라 와(과) 카엘 의 관계가 적대(으)로 바뀐다")
        self.assertEqual(describe_event({"type": "mark", "who": "카엘", "with": "세라", "fact": "약속"}), "'약속' 이(가) 성립한다(카엘, 세라)")

    def test_the_scenes_question_goes_into_the_brief(self):
        state = build_initial_state(sample_world())
        brief = build_brief({**SCENE_CARD, "question": "세라를 믿을 것인가"}, state)
        self.assertIn("독자에게 묻는 것: 세라를 믿을 것인가", brief)
        self.assertNotIn("독자에게 묻는 것", build_brief(SCENE_CARD, state))


class DiverseChoiceTest(unittest.TestCase):
    def choice(self, choice_id, lasting, events=(), label=""):
        return {"id": choice_id, "lasting": lasting, "events": list(events), "label": label}

    def test_one_choice_involving_another_character_is_kept_when_available(self):
        from app.services.story_skeleton import pick_diverse_choices

        offered = [
            self.choice("a", False, label="차분하게 말한다"),
            self.choice("b", True, [{"type": "mark", "who": "카엘", "fact": "x"}]),
            self.choice("c", True, [{"type": "mark", "who": "카엘", "fact": "y"}]),
            self.choice("d", False, label="세라의 손을 잡는다"),
        ]
        picked = [choice["id"] for choice in pick_diverse_choices(offered, 3, others=["세라", "도윤"])]
        self.assertEqual(picked, ["a", "b", "d"])  # d brings in 세라; c only repeats what b does

    def test_partners_in_events_count_as_involving_others(self):
        from app.services.story_skeleton import pick_diverse_choices

        offered = [
            self.choice("a", False),
            self.choice("b", True, [{"type": "mark", "who": "카엘", "fact": "x"}]),
            self.choice("c", True, [{"type": "give", "who": "카엘", "to": "도윤", "item": "단검"}]),
        ]
        self.assertEqual([choice["id"] for choice in pick_diverse_choices(offered, 2, others=["도윤"])], ["a", "c"])

    def test_without_variety_choices_are_still_offered(self):
        from app.services.story_skeleton import pick_diverse_choices

        offered = [self.choice(str(n), False) for n in range(4)]
        self.assertEqual([choice["id"] for choice in pick_diverse_choices(offered, 3)], ["0", "1", "2"])


class CallbackTest(unittest.TestCase):
    def test_only_reader_choices_in_the_brief_are_callbacks(self):
        from app.services.story_skeleton import brief_callbacks

        state = mark(build_initial_state(sample_world()), "choice", "카엘", "카엘이 돌아오겠다고 약속했다")
        state = mark(state, "scene", "카엘", "카엘이 말에게 물을 먹였다")
        state = mark(state, "choice", "도윤", "도윤이 비밀을 지키기로 했다")  # 도윤 is not in this scene
        self.assertEqual(brief_callbacks(SCENE_CARD, state), ["카엘이 돌아오겠다고 약속했다"])

if __name__ == "__main__":
    unittest.main()
