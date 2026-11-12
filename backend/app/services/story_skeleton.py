"""Skeleton checks for skeleton-mode stories.

A story is planned as a spine of major events. The scenes between two major
events are a segment, planned as beat cards. This module checks that plan with
code only (no database, no LLM):

- build_brief: the facts a scene needs, picked from the state for the writer.
- walk_cards / check_segment: do the cards of a segment hold, and do they end
  where the next major event can start.
- walk_spine / check_spine: do the major events hold in order. A need that the
  scenes in between can still satisfy is a gap (the segment's task); one they
  cannot satisfy (a dead character is required) is an error.
- check_craft: dramatic form (a cost at the end, agency, a tension curve).
  It checks form only, not whether the story is convincing.
- offer_choices: which reader choices may be shown after a scene.

Functions return new states and never mutate the one they receive.

Spine event shape (story_plans.spine):
    {
        "id": "e04", "when": 10, "title": "Betrayal", "meaning": "...",
        "intensity": 3, "dilemma": "...", "cost": "...",
        "needs": [["together", "Sera", "Kael"], ["fact", "the ambush was betrayed"]],
        "events": [{"type": "relate", "a": "Sera", "b": "Kael", "kind": "enemy"}],
        "because": ["e01"], "plants": [], "pays": ["Sera's hesitation"],
    }

Need kinds: ["alive", X], ["at", X, location], ["together", X, Y],
["has", X, item], ["rel", X, Y, kind], ["fact", name].

Beat card shape (story_beats.card):
    {
        "id": "s1", "title": "...", "fixed": [events], "uses": [items],
        "open": ["..."], "plants": [], "pays": [], "needs": [needs],
        "choices": [{"id": "c1", "label": "...", "events": [events]}],
    }
"""

import math
from dataclasses import dataclass, field
from typing import Any, Collection, Dict, List, Optional, Sequence, Set, Tuple

from app.services.story_state import (
    LOSS_RELATION_KINDS,
    RELATION_LABELS,
    EventRejected,
    Event,
    State,
    apply_event,
    build_initial_state,
    diff_states,
    relation_key,
)

Need = Sequence[Any]
Card = Dict[str, Any]
SpineEvent = Dict[str, Any]
Problem = Tuple[str, str]  # (event or card id, or "story" for the whole spine, reason)

# Fact importance. It is decided by where the fact was established, not by the model.
CORE, CHOICE, SCENE = 3, 2, 1
FACT_LABELS = {CORE: "사실", CHOICE: "독자의 선택", SCENE: "최근의 일"}
ROLE_LABELS = {"protagonist": "주인공", "ally": "조력자", "antagonist": "적대자", "neutral": "주변 인물"}
FACTS_IN_BRIEF = 8
# Per-tier caps inside the brief, so minor facts cannot push out important ones.
FACT_TIER_CAPS = {CHOICE: 4, SCENE: 2}
# A character needed again after this many major events without appearing is flagged.
REAPPEAR_AFTER = 3

CHARACTER_KEYS = ("who", "with", "a", "b", "to")
NEED_PEOPLE_COUNT = {"alive": 1, "at": 1, "together": 2, "has": 1, "rel": 2, "fact": 0}
WHOLE_STORY = "전체"


@dataclass
class CardResult:
    id: str
    brief: str
    errors: List[str] = field(default_factory=list)


@dataclass
class SpineEventResult:
    id: str
    gaps: List[Tuple[Any, ...]] = field(default_factory=list)  # what the segment before must set up
    errors: List[str] = field(default_factory=list)  # what no segment can set up


@dataclass
class SpineReport:
    errors: List[Problem]
    warnings: List[str]
    events: List[SpineEventResult]


# ---------- facts: importance and selection ----------


def fact_tier(fact_name: str, record: Dict[str, Any], core_facts: Collection[str] = ()) -> int:
    """Core if the spine defined or established it, choice if a reader choice did, else scene."""
    if fact_name in core_facts or record.get("origin") == "spine":
        return CORE
    return CHOICE if record.get("origin") == "choice" else SCENE


def select_brief_facts(
    card: Card, state: State, core_facts: Collection[str], nearby: Set[str]
) -> List[Tuple[int, str]]:
    """Pick the facts that go into a scene's brief, as (tier, name), highest tier first.

    Facts the scene lists as needs are always included. The rest are the facts
    tied to the people in the scene, most important and most recent first,
    within the per-tier caps.
    """
    facts = state.get("facts") or {}
    position = {name: index for index, name in enumerate(facts)}
    tiers = {name: fact_tier(name, record, core_facts) for name, record in facts.items()}
    required = [need[1] for need in card.get("needs") or [] if need[0] == "fact" and need[1] in facts]
    picked = list(dict.fromkeys(required))
    used_per_tier: Dict[int, int] = {}
    candidates = [
        name
        for name, record in facts.items()
        if name not in picked and (not record["people"] or nearby & set(record["people"]))
    ]
    for name in sorted(candidates, key=lambda fact: (-tiers[fact], -position[fact])):
        tier = tiers[name]
        if len(picked) >= FACTS_IN_BRIEF or used_per_tier.get(tier, 0) >= FACT_TIER_CAPS.get(tier, FACTS_IN_BRIEF):
            continue
        picked.append(name)
        used_per_tier[tier] = used_per_tier.get(tier, 0) + 1
    labelled = [(CORE if name in required else tiers[name], name) for name in picked]
    return sorted(labelled, key=lambda entry: (-entry[0], position[entry[1]]))


def forget_scene_facts(state: State, core_facts: Collection[str] = ()) -> State:
    """Drop scene-tier facts. Called when a major event ends so the state does not fill with minor facts."""
    facts = state.get("facts") or {}
    kept = {name: record for name, record in facts.items() if fact_tier(name, record, core_facts) != SCENE}
    return {**state, "facts": kept}


# ---------- briefs and beat cards ----------


def scene_cast(card: Card, state: State) -> Tuple[List[str], List[str]]:
    """Characters named in the card's events, and items its events or 'uses' refer to."""
    characters: List[str] = []
    items: List[str] = list(card.get("uses") or [])
    for event in card.get("fixed") or []:
        characters += [event[key] for key in CHARACTER_KEYS if event.get(key) in state["chars"]]
        if event.get("item"):
            items.append(event["item"])
    return list(dict.fromkeys(characters)), list(dict.fromkeys(items))


def _bystanders(characters: List[str], state: State) -> List[str]:
    """Living characters at the same place as the cast who are not in the events."""
    chars = state["chars"]
    places = {chars[name]["at"] for name in characters if chars[name]["alive"]}
    return [name for name in chars if name not in characters and chars[name]["alive"] and chars[name]["at"] in places]


def _state_lines(characters: List[str], bystanders: List[str], items: List[str], state: State) -> List[str]:
    chars = state["chars"]
    described = [f"{name}({chars[name]['at'] if chars[name]['alive'] else '사망'})" for name in characters]
    lines = ["인물: " + ", ".join(described)]
    if bystanders:
        lines.append("같은 장소: " + ", ".join(bystanders))
    lines += [f"물건: {item} — {state['items'].get(item, '소지자 없음')}" for item in items]
    for index, first in enumerate(characters):
        for second in characters[index + 1:]:
            kind = state["rels"].get(relation_key(first, second))
            if kind:
                lines.append(f"관계: {relation_key(first, second)} {RELATION_LABELS.get(kind, kind)}")
    return lines


def build_brief(card: Card, state: State, core_facts: Collection[str] = ()) -> str:
    """The facts a writer needs for one scene, read from the state on entering it.

    Only what the scene reads goes in, so the brief stays the same size however
    long the story gets. Two scenes with the same brief need the same prose.
    """
    characters, items = scene_cast(card, state)
    bystanders = _bystanders(characters, state)
    lines = [f"장면: {card['id']} {card.get('title', '')}".rstrip()]
    lines += _state_lines(characters, bystanders, items, state)
    nearby = set(characters) | set(bystanders)
    lines += [f"{FACT_LABELS[tier]}: {name}" for tier, name in select_brief_facts(card, state, core_facts, nearby)]
    lines += [f"반드시: {describe_event(event)}" for event in card.get("fixed") or []]
    if card.get("question"):
        lines.append(f"독자에게 묻는 것: {card['question']}")
    for key, label in (("open", "열린 부분"), ("plants", "복선 심기"), ("pays", "복선 회수")):
        if card.get(key):
            lines.append(f"{label}: " + ", ".join(card[key]))
    return "\n".join(lines)


def describe_event(event: Event) -> str:
    """One event as a sentence for a writer."""
    event_type = event.get("type")
    if event_type == "act":
        partner = f" {event['with']}와(과) 마주하여" if event.get("with") else ""
        return f"{event.get('who')} 이(가){partner} 직접 행동한다"
    if event_type == "move":
        return f"{event.get('who')} 이(가) {event.get('to')}(으)로 간다"
    if event_type == "die":
        return f"{event.get('who')} 이(가) 죽는다"
    if event_type == "give":
        return f"{event.get('who')} 이(가) {event.get('to')}에게 {event.get('item')} 을(를) 건넨다"
    if event_type == "relate":
        kind = RELATION_LABELS.get(event.get("kind"), event.get("kind"))
        return f"{event.get('a')} 와(과) {event.get('b')} 의 관계가 {kind}(으)로 바뀐다"
    if event_type == "mark":
        people = ", ".join(name for name in (event.get("who"), event.get("with")) if name)
        return f"'{event.get('fact')}' 이(가) 성립한다({people})"
    return str(event)


def _check_used_items(card: Card, state: State) -> List[str]:
    characters, _ = scene_cast(card, state)
    errors = []
    for item in card.get("uses") or []:
        holder = state["items"].get(item)
        if item not in state["items"]:
            errors.append(f"'{item}' 은(는) 정의되지 않은 물건이다")
        elif holder not in characters or not state["chars"][holder]["alive"]:
            errors.append(f"이 장면의 인물 가운데 '{item}' 을(를) 가진 사람이 없다(소지자: {holder})")
    return errors


def walk_cards(
    state: State, cards: Sequence[Card], core_facts: Collection[str] = (), origin: str = "scene"
) -> Tuple[List[CardResult], State]:
    """Apply cards in order. An event that does not hold is recorded and skipped, so one pass finds every problem."""
    results = []
    for card in cards:
        result = CardResult(str(card.get("id")), build_brief(card, state, core_facts))
        result.errors += _check_used_items(card, state)
        for event in card.get("fixed") or []:
            try:
                state = apply_event(state, event, origin)
            except EventRejected as rejection:
                result.errors.append(str(rejection))
        results.append(result)
    return results, state


# ---------- needs ----------


def describe_need(need: Need) -> str:
    kind, *args = need
    templates = {
        "alive": "{0} 이(가) 살아 있다",
        "at": "{0} 이(가) {1}에 있다",
        "together": "{0} 와(과) {1} 이(가) 같은 장소에 있다",
        "has": "{0} 이(가) {1} 을(를) 갖고 있다",
        "rel": "{0} 와(과) {1} 의 관계가 {2}",
        "fact": "'{0}' 이(가) 성립해 있다",
    }
    if kind == "rel":
        args = [*args[:2], RELATION_LABELS.get(args[2], args[2])]
    return templates.get(kind, f"{kind} {args}").format(*args)


def _need_people(need: Need) -> List[str]:
    kind, *args = need
    return list(args[: NEED_PEOPLE_COUNT[kind]])


def find_unknown_name(state: State, need: Need, core_facts: Optional[Collection[str]]) -> Optional[str]:
    """Return a reason if the need refers to a name that is not defined."""
    kind, *args = need
    if kind not in NEED_PEOPLE_COUNT:
        return f"정의되지 않은 조건: {kind}"
    if kind == "fact":
        # When the spine fixed a fact list, the name must be on it. This catches names that drift.
        return f"'{args[0]}' 은(는) 정의되지 않은 사실이다" if core_facts is not None and args[0] not in core_facts else None
    for name in _need_people(need):
        if name not in state["chars"]:
            return f"'{name}' 은(는) 등장인물이 아니다"
    if kind == "at" and args[1] not in state["locations"]:
        return f"'{args[1]}' 은(는) 정의되지 않은 장소다"
    if kind == "has" and args[1] not in state["items"]:
        return f"'{args[1]}' 은(는) 정의되지 않은 물건이다"
    return None


def need_holds(state: State, need: Need) -> bool:
    kind, *args = need
    chars = state["chars"]
    if kind == "fact":
        return args[0] in (state.get("facts") or {})
    if not all(chars[name]["alive"] for name in _need_people(need)):
        return False
    if kind == "at":
        return chars[args[0]]["at"] == args[1]
    if kind == "together":
        return chars[args[0]]["at"] == chars[args[1]]["at"]
    if kind == "has":
        return state["items"][args[1]] == args[0]
    if kind == "rel":
        return state["rels"].get(relation_key(args[0], args[1])) == args[2]
    return True


def need_is_recoverable(state: State, need: Need) -> bool:
    """Can the scenes in between still satisfy an unmet need. Not if a dead character is involved."""
    kind, *args = need
    chars = state["chars"]
    if kind == "fact":
        return True  # someone can establish it in a scene in between
    if kind == "alive":
        return False
    if not all(chars[name]["alive"] for name in _need_people(need)):
        return False
    if kind == "has":
        # An item only moves when its living holder hands it over.
        return chars[state["items"][args[1]]]["alive"]
    return True


def _explain_lost_need(state: State, need: Need) -> str:
    kind, *args = need
    dead = [name for name in _need_people(need) if not state["chars"][name]["alive"]]
    if dead:
        return f"{dead[0]} 은(는) 이미 죽었다"
    return f"{args[1]} 을(를) 가진 {state['items'][args[1]]} 이(가) 이미 죽었다"  # only "has" reaches here


def _assume_need(state: State, need: Need) -> State:
    """Return the state as if the segment before had satisfied this need."""
    kind, *args = need
    if kind == "at":
        return apply_event(state, {"type": "move", "who": args[0], "to": args[1]}, "spine")
    if kind == "together":
        return apply_event(state, {"type": "move", "who": args[1], "to": state["chars"][args[0]]["at"]}, "spine")
    if kind == "has":
        return {**state, "items": {**state["items"], args[1]: args[0]}}
    if kind == "rel":
        return {**state, "rels": {**state["rels"], relation_key(args[0], args[1]): args[2]}}
    if kind == "fact":
        return {**state, "facts": {**(state.get("facts") or {}), args[0]: {"people": [], "origin": "spine"}}}
    return state


def event_needs(event: Event) -> List[Tuple[Any, ...]]:
    """What must hold for one event to apply. Added by code even when the planner left it out."""
    event_type = event.get("type")
    if event_type == "act":
        return [("together", event["who"], event["with"])] if event.get("with") else [("alive", event["who"])]
    if event_type in ("move", "die", "mark"):
        return [("alive", event["who"])]
    if event_type == "give":
        return [("together", event["who"], event["to"]), ("has", event["who"], event["item"])]
    if event_type == "relate":
        return [("alive", event["a"]), ("alive", event["b"])]
    return []


# ---------- spine ----------


def _require_need(
    state: State, need: Need, result: SpineEventResult, core_facts: Optional[Collection[str]]
) -> State:
    """Check one need. A recoverable gap is recorded and assumed filled; anything else is an error."""
    need = tuple(need)
    unknown = find_unknown_name(state, need, core_facts)
    if unknown:
        result.errors.append(unknown)
        return state
    if need_holds(state, need):
        return state
    if need_is_recoverable(state, need):
        result.gaps.append(need)
        return _assume_need(state, need)
    result.errors.append(f"{_explain_lost_need(state, need)} — 필요한 조건: {describe_need(need)}")
    return state


def _enter_spine_event(
    state: State, spine_event: SpineEvent, core_facts: Optional[Collection[str]]
) -> Tuple[SpineEventResult, State]:
    result = SpineEventResult(str(spine_event.get("id")))
    for need in spine_event.get("needs") or []:
        state = _require_need(state, need, result, core_facts)
    for event in spine_event.get("events") or []:
        try:
            for need in event_needs(event):
                state = _require_need(state, need, result, core_facts)
            state = apply_event(state, event, "spine")
        except EventRejected as rejection:
            subject = str(rejection).split(" 은(는)")[0]
            if not any(subject in known_error for known_error in result.errors):  # do not report one cause twice
                result.errors.append(str(rejection))
        except KeyError as missing_key:
            result.errors.append(f"사건에 필요한 값이 없다: {missing_key}")
    return result, state


def walk_spine(
    state: State, spine_events: Sequence[SpineEvent], core_facts: Optional[Collection[str]] = None
) -> Tuple[List[SpineEventResult], State]:
    """Apply major events in order from a state.

    core_facts is the spine's fact list. Pass None to skip the name check.
    Scene-tier facts are forgotten after each major event.
    """
    results = []
    for spine_event in spine_events:
        result, state = _enter_spine_event(state, spine_event, core_facts)
        state = forget_scene_facts(state, core_facts or ())
        results.append(result)
    return results, state


def spine_event_cast(spine_event: SpineEvent, character_names: Collection[str]) -> List[str]:
    """Characters a major event involves: those in its events and in its needs."""
    names = [event.get(key) for event in spine_event.get("events") or [] for key in CHARACTER_KEYS]
    names += [name for need in spine_event.get("needs") or [] for name in need[1:3]]
    return list(dict.fromkeys(name for name in names if name in character_names))


def characters_to_reintroduce(world: Dict[str, Any]) -> List[List[str]]:
    """Per major event, the characters needed again after a long absence."""
    last_seen: Dict[str, int] = {}
    per_event = []
    for index, spine_event in enumerate(world.get("spine") or []):
        cast = spine_event_cast(spine_event, world["characters"])
        per_event.append([name for name in cast if name in last_seen and index - last_seen[name] > REAPPEAR_AFTER])
        last_seen.update({name: index for name in cast})
    return per_event


def _check_order(spine_events: Sequence[SpineEvent]) -> List[Problem]:
    """Ids are unique, time does not run backwards, and every event after the first has an earlier cause."""
    errors: List[Problem] = []
    seen_ids: Set[str] = set()
    latest_day: Optional[int] = None
    for index, spine_event in enumerate(spine_events):
        event_id = str(spine_event.get("id"))
        if event_id in seen_ids:
            errors.append((event_id, "사건 ID 가 겹친다"))
        day = spine_event.get("when")
        if not isinstance(day, int):
            errors.append((event_id, "시점(when)이 정수가 아니다"))
        elif latest_day is not None and day < latest_day:
            errors.append((event_id, f"시간이 거꾸로 간다({latest_day}일 → {day}일)"))
        else:
            latest_day = day
        causes = spine_event.get("because") or []
        if index and not causes:
            errors.append((event_id, "원인(because)이 없다"))
        errors += [(event_id, f"원인 '{cause}' 이(가) 앞선 사건이 아니다") for cause in causes if cause not in seen_ids]
        seen_ids.add(event_id)
    return errors


def _check_fact_names(
    spine_events: Sequence[SpineEvent], core_facts: Optional[Collection[str]]
) -> Tuple[List[Problem], List[str]]:
    if core_facts is None:
        return [], []
    established = [
        (str(spine_event.get("id")), event.get("fact"))
        for spine_event in spine_events
        for event in spine_event.get("events") or []
        if event.get("type") == "mark"
    ]
    errors = [(event_id, f"'{name}' 은(는) 정의되지 않은 사실이다") for event_id, name in established if name not in core_facts]
    needed = {need[1] for spine_event in spine_events for need in spine_event.get("needs") or [] if need[0] == "fact"}
    used = {name for _, name in established} | needed
    warnings = [f"사실 '{name}' 이(가) 어느 주요 사건에서도 쓰이지 않는다" for name in core_facts if name not in used]
    return errors, warnings


def _check_foreshadowing(spine_events: Sequence[SpineEvent]) -> Tuple[List[Problem], List[str]]:
    errors: List[Problem] = []
    planted: Dict[str, str] = {}
    paid: Set[str] = set()
    for spine_event in spine_events:
        event_id = str(spine_event.get("id"))
        for hook in spine_event.get("pays") or []:
            if hook not in planted:
                errors.append((event_id, f"심지 않은 복선을 회수한다: {hook}"))
            paid.add(hook)
        for hook in spine_event.get("plants") or []:
            planted.setdefault(hook, event_id)
    warnings = [f"{event_id}: 복선 '{hook}' 이(가) 끝까지 회수되지 않는다" for hook, event_id in planted.items() if hook not in paid]
    return errors, warnings


def check_spine(world: Dict[str, Any]) -> SpineReport:
    """Check the whole spine. Errors must be fixed; warnings are things to look at."""
    spine_events = world.get("spine") or []
    core_facts = world.get("facts")
    results, _ = walk_spine(build_initial_state(world), spine_events, core_facts)
    errors = [(result.id, reason) for result in results for reason in result.errors]
    errors += _check_order(spine_events)
    fact_errors, warnings = _check_fact_names(spine_events, core_facts)
    hook_errors, hook_warnings = _check_foreshadowing(spine_events)
    errors += fact_errors + hook_errors
    warnings += hook_warnings

    appearing = {name for spine_event in spine_events for name in spine_event_cast(spine_event, world["characters"])}
    warnings += [f"{name} 이(가) 어느 주요 사건에도 나오지 않는다" for name in world["characters"] if name not in appearing]
    for index, names in enumerate(characters_to_reintroduce(world)):
        event_id = spine_events[index]["id"]
        warnings += [f"{event_id}: {name} 이(가) 오랜만에 나온다. 앞 구간에서 다시 등장시켜야 한다" for name in names]
    return SpineReport(errors, warnings, results)


def segment_task(world: Dict[str, Any], index: int) -> Dict[str, Any]:
    """What the segment before major event `index` must do: gaps to fill, days that pass, who to reintroduce."""
    spine_events = world["spine"]
    results, _ = walk_spine(build_initial_state(world), spine_events[: index + 1], world.get("facts"))
    days = spine_events[index]["when"] - spine_events[index - 1]["when"] if index else 0
    return {"gaps": results[index].gaps, "days": days, "reintroduce": characters_to_reintroduce(world)[index]}


def check_segment(
    state: State, cards: Sequence[Card], target_event: SpineEvent, core_facts: Optional[Collection[str]] = None
) -> Tuple[List[Problem], List[Tuple[Any, ...]]]:
    """Apply a segment's cards from a state and see whether the next major event can start right after.

    Returns (card errors, needs of the target that are still unmet).
    """
    results, end_state = walk_cards(state, cards, core_facts or ())
    errors: List[Problem] = [(result.id, reason) for result in results for reason in result.errors]
    (target_result,), _ = walk_spine(end_state, [target_event], core_facts)
    errors += [(target_result.id, reason) for reason in target_result.errors]
    return errors, target_result.gaps


# ---------- craft ----------


def event_actors(spine_event: SpineEvent) -> List[str]:
    """Characters who act on their own in a major event, in order. Dying and receiving do not count."""
    actors: List[Any] = []
    for event in spine_event.get("events") or []:
        event_type = event.get("type")
        if event_type == "relate":
            actors += [event.get("a"), event.get("b")]
        elif event_type != "die":
            actors.append(event.get("who"))
    return list(dict.fromkeys(name for name in actors if name))


def _check_event_fields(spine_events: Sequence[SpineEvent], hero: Optional[str]) -> List[Problem]:
    problems: List[Problem] = []
    for spine_event in spine_events:
        event_id = str(spine_event.get("id"))
        intensity = spine_event.get("intensity")
        if not isinstance(intensity, int) or not 1 <= intensity <= 5:
            problems.append((event_id, "강도(intensity)가 1~5 의 정수가 아니다"))
        elif intensity >= 3 and not (spine_event.get("cost") or "").strip():
            problems.append((event_id, "강도 3 이상인 사건인데 대가(cost)가 비어 있다"))
        if hero in event_actors(spine_event) and not (spine_event.get("dilemma") or "").strip():
            problems.append((event_id, "주인공이 행동하는 사건인데 딜레마(dilemma)가 비어 있다"))
    return problems


def _check_ending_cost(final_events: Sequence[SpineEvent], hero: Optional[str]) -> List[Problem]:
    """The last third must hold a death, a broken relation, or the protagonist giving something up."""
    for spine_event in final_events:
        for event in spine_event.get("events") or []:
            event_type = event.get("type")
            if event_type == "die":
                return []
            if event_type == "relate" and event.get("kind") in LOSS_RELATION_KINDS:
                return []
            if event_type == "give" and (hero is None or event.get("who") == hero):
                return []
    return [(WHOLE_STORY, f"마지막 {len(final_events)}개 사건에 되돌릴 수 없는 대가(죽음, 관계의 단절, 주인공이 무언가를 내놓음)가 없다")]


def _check_agency(world: Dict[str, Any], acting: Sequence[List[str]]) -> List[Problem]:
    problems: List[Problem] = []
    event_count = len(acting)
    hero = world.get("viewpoint")
    if hero:
        if acting and hero not in acting[0]:
            problems.append((WHOLE_STORY, "첫 사건에서 주인공이 행동하지 않는다(첫 장면은 주인공의 장면이어야 한다)"))
        hero_events = sum(hero in actors for actors in acting)
        if hero_events * 2 < event_count:
            problems.append((WHOLE_STORY, f"주인공이 직접 행동하는 사건이 {event_count}개 중 {hero_events}개뿐이다(절반 이상 필요)"))
    roles = {name: character.get("role") for name, character in world["characters"].items()}
    antagonists = [name for name, role in roles.items() if role == "antagonist"]
    if antagonists:
        moves_first = sum(bool(actors) and actors[0] in antagonists for actors in acting)
        required = max(1, event_count // 5)
        if moves_first < required:
            problems.append((WHOLE_STORY, f"적대자가 먼저 움직이는 사건이 {moves_first}개뿐이다({required}개 이상 필요)"))
    for name, role in roles.items():
        if role in ("ally", "antagonist") and not any(name in actors for actors in acting):
            problems.append((WHOLE_STORY, f"{name}({ROLE_LABELS.get(role, role)}) 이(가) 어느 사건에서도 직접 행동하지 않는다"))
    return problems


def _check_intensity_curve(spine_events: Sequence[SpineEvent], third: int) -> List[Problem]:
    levels = [spine_event.get("intensity") for spine_event in spine_events]
    if not all(isinstance(level, int) for level in levels):
        return []
    event_count = len(levels)
    problems: List[Problem] = []
    peak = max(range(event_count), key=lambda index: (levels[index], index))  # the highest event, the later one on ties
    if peak < event_count - third:
        problems.append((WHOLE_STORY, f"강도가 가장 높은 사건({spine_events[peak].get('id')})이 마지막 {third}개 안에 없다"))
    if sum(levels[-third:]) / third <= sum(levels[:third]) / third:
        problems.append((WHOLE_STORY, "뒤로 갈수록 강도가 오르지 않는다(마지막 3분의 1의 평균이 처음 3분의 1보다 높아야 한다)"))
    second_half = range(max(1, math.ceil(event_count / 2)), peak)
    if not any(levels[index] < levels[index - 1] for index in second_half):
        problems.append((WHOLE_STORY, "후반부에 절정을 앞두고 강도가 한 번 꺾이는 사건이 없다"))
    return problems


def check_craft(world: Dict[str, Any]) -> List[Problem]:
    """Check dramatic form: fields, a cost at the end, agency, and the tension curve.

    It only sees whether the form is there. It cannot tell whether a cost carries weight.
    Checks that need a protagonist or roles are skipped when the world has none.
    """
    spine_events = world.get("spine") or []
    if len(spine_events) < 3:
        return []
    third = math.ceil(len(spine_events) / 3)
    hero = world.get("viewpoint")
    problems = _check_event_fields(spine_events, hero)
    problems += _check_ending_cost(spine_events[-third:], hero)
    problems += _check_agency(world, [event_actors(spine_event) for spine_event in spine_events])
    problems += _check_intensity_curve(spine_events, third)
    return problems


# ---------- reader choices ----------


def choice_changes_state(choice: Dict[str, Any]) -> bool:
    """Is the choice meant to leave a trace. Talking to someone (act) alone leaves nothing behind.

    This looks at the event types only. Use choice_leaves_trace when a state is at hand:
    re-establishing a fact that already holds is a 'mark' that changes nothing.
    """
    return any(event.get("type") != "act" for event in choice.get("events") or [])


def choice_leaves_trace(state: State, choice: Dict[str, Any]) -> bool:
    """Does picking the choice in this state actually change the state."""
    after_choice = _apply_choice(state, choice)
    return after_choice is not None and bool(diff_states(state, after_choice))


def _apply_choice(state: State, choice: Dict[str, Any]) -> Optional[State]:
    try:
        for event in choice.get("events") or []:
            state = apply_event(state, event, "choice")
    except EventRejected:
        return None
    return state


def _choice_features(choice: Dict[str, Any], others: Collection[str]) -> Set[str]:
    """What makes a choice different from another: whether it lasts, what it does, and who else it involves."""
    features = {"lasting" if choice.get("lasting") else "quiet"}
    for event in choice.get("events") or []:
        features.add(f"type:{event.get('type')}")
        features |= {f"with:{event[key]}" for key in ("with", "to", "b") if event.get(key) in others}
    label = choice.get("label") or ""
    features |= {f"with:{name}" for name in others if name and name in label}
    if any(feature.startswith("with:") for feature in features):
        features.add("involves_other")
    return features


def pick_diverse_choices(offered: Sequence[Dict[str, Any]], wanted: int, others: Collection[str] = ()) -> List[Dict[str, Any]]:
    """Pick `wanted` choices that differ as much as possible, keeping the card's order.

    First one that changes nothing (an attitude), one that leaves a trace, and
    one that involves another character, when available. Then, one at a time,
    the choice that adds the most it does not share with those already picked.
    `others` are the characters other than the one the reader chooses for.
    Nothing is rejected here: a card without a variety still yields choices.
    """
    features = [_choice_features(choice, others) for choice in offered]
    picked: List[int] = []
    covered: Set[str] = set()

    def most_new(candidates: List[int]) -> int:
        return max(candidates, key=lambda index: (len(features[index] - covered), -index))

    for required in ("quiet", "lasting", "involves_other"):
        candidates = [index for index, feature in enumerate(features) if index not in picked and required in feature]
        if len(picked) < wanted and required not in covered and candidates:
            picked.append(most_new(candidates))
            covered |= features[picked[-1]]
    while len(picked) < min(wanted, len(offered)):
        picked.append(most_new([index for index in range(len(offered)) if index not in picked]))
        covered |= features[picked[-1]]
    return [offered[index] for index in sorted(picked)]


def offer_choices(
    state: State,
    card: Card,
    remaining_cards: Sequence[Card],
    remaining_spine: Sequence[SpineEvent],
    core_facts: Optional[Collection[str]] = None,
    wanted: int = 3,
    others: Collection[str] = (),
) -> List[Dict[str, Any]]:
    """Choices to show after a scene. `state` already includes the scene's own events.

    Choices that do not hold, and choices that make a remaining major event
    impossible, are left out. Each offered choice carries `replan` (the rest of
    this segment must be planned again) and `lasting` (picking it changes the
    state). The ones shown are picked for variety by pick_diverse_choices.
    """
    offered = []
    for choice in card.get("choices") or []:
        after_choice = _apply_choice(state, choice)
        if after_choice is None:
            continue
        spine_results, _ = walk_spine(after_choice, remaining_spine, core_facts)
        if any(result.errors for result in spine_results):
            continue
        needs_replan = False
        if remaining_spine:
            errors, unmet = check_segment(after_choice, remaining_cards, remaining_spine[0], core_facts)
            needs_replan = bool(errors or unmet)
        offered.append({**choice, "replan": needs_replan, "lasting": bool(diff_states(state, after_choice))})
    return pick_diverse_choices(offered, wanted, others)


def why_choices_drop(
    state: State,
    card: Card,
    remaining_spine: Sequence[SpineEvent],
    core_facts: Optional[Collection[str]] = None,
) -> List[str]:
    """Why the card's choices are left out or leave no trace in this state, one line each, so the planner's
    next try can fix them. Mirrors offer_choices."""
    reasons = []
    for choice in card.get("choices") or []:
        label, after_choice = f"「{choice.get('label')}」", state
        try:
            for event in choice.get("events") or []:
                after_choice = apply_event(after_choice, event, "choice")
        except EventRejected as rejection:
            reasons.append(f"{label} 은(는) 성립하지 않는다: {rejection}")
            continue
        if any(result.errors for result in walk_spine(after_choice, remaining_spine, core_facts)[0]):
            reasons.append(f"{label} 은(는) 뒤의 주요 사건을 불가능하게 만든다")
        elif choice_changes_state(choice) and not diff_states(state, after_choice):
            reasons.append(f"{label} 은(는) 아무것도 바꾸지 않는다(이미 그렇다)")
    return reasons


def brief_callbacks(card: Card, state: State, core_facts: Collection[str] = ()) -> List[str]:
    """The reader's earlier choices that a scene's brief carries, to show the reader that they still count."""
    characters, _ = scene_cast(card, state)
    nearby = set(characters) | set(_bystanders(characters, state))
    return [name for tier, name in select_brief_facts(card, state, core_facts, nearby) if tier == CHOICE]
