"""World state for skeleton-mode stories.

The state is the source of truth for who is alive, where they are, who holds
what, how characters relate, and which facts have been established. Prose never
changes it: only declared events do, and an event whose preconditions do not
hold is rejected. Functions here are pure: they never touch the database or an
LLM, and they return a new state instead of mutating the one they receive.

State shape (stored as stories.world_state):
    {
        "locations": ["castle", "forest"],
        "chars": {"Kael": {"alive": True, "at": "castle"}},
        "items": {"silver dagger": "Doyun"},            # item -> holder
        "rels": {"Kael·Sera": "ally"},                   # sorted pair -> kind
        "facts": {"Sera's betrayal is revealed": {"people": ["Sera"], "origin": "spine"}},
    }

Event shape (stored in scenes.events and beat cards):
    {"type": "act", "who": "Kael", "with": "Sera"}       # "with" is optional
    {"type": "move", "who": "Kael", "to": "forest"}
    {"type": "die", "who": "Doyun"}
    {"type": "give", "who": "Doyun", "to": "Kael", "item": "silver dagger"}
    {"type": "relate", "a": "Sera", "b": "Kael", "kind": "enemy"}
    {"type": "mark", "who": "Kael", "with": "Sera", "fact": "Kael promised to return"}
"""

import copy
from dataclasses import dataclass
from typing import Any, Callable, Dict, Iterable, List, Optional

State = Dict[str, Any]
Event = Dict[str, Any]

RELATION_KINDS = ("ally", "enemy", "lover", "family", "stranger")
# How relation kinds read in prompts and briefs. The stored values stay language-neutral.
RELATION_LABELS = {"ally": "동맹", "enemy": "적대", "lover": "연인", "family": "가족", "stranger": "남남"}
# A relation moving to one of these counts as a loss (used by the ending-cost check).
LOSS_RELATION_KINDS = ("enemy", "stranger")
EVENT_TYPES = ("act", "move", "die", "give", "relate", "mark")
# Where a fact was established. It decides how important the fact is.
FACT_ORIGINS = ("spine", "choice", "scene")

MAX_NAME_LENGTH = 60
MAX_FACT_LENGTH = 80
PAIR_SEPARATOR = "·"


class EventRejected(Exception):
    """An event's preconditions do not hold in the current state."""


@dataclass(frozen=True)
class StateChange:
    entity: str
    attribute: str
    before: Optional[str]
    after: Optional[str]


def relation_key(first_name: str, second_name: str) -> str:
    """Relations are undirected, so the pair is stored in sorted order."""
    return PAIR_SEPARATOR.join(sorted((first_name, second_name)))


def clean_name(raw_name: Any, max_length: int = MAX_NAME_LENGTH) -> str:
    """Collapse whitespace and cap the length. Names end up back in prompts."""
    return " ".join(str(raw_name or "").split())[:max_length]


def build_initial_state(world: Dict[str, Any]) -> State:
    """Build the starting state from a world definition (story_plans.world)."""
    return {
        "locations": list(world.get("locations") or []),
        "chars": {
            name: {"alive": True, "at": character["at"]}
            for name, character in (world.get("characters") or {}).items()
        },
        "items": {name: item["holder"] for name, item in (world.get("items") or {}).items()},
        "rels": {
            relation_key(first, second): kind
            for first, second, kind in world.get("relations") or []
        },
        "facts": {},
    }


def _require_alive(state: State, name: Any) -> Dict[str, Any]:
    character = state["chars"].get(name)
    if character is None:
        raise EventRejected(f"'{name}' 은(는) 등장인물이 아니다")
    if not character["alive"]:
        raise EventRejected(f"{name} 은(는) 이미 죽었다")
    return character


def _require_together(state: State, first_name: Any, second_name: Any) -> None:
    first = _require_alive(state, first_name)
    second = _require_alive(state, second_name)
    if first["at"] != second["at"]:
        raise EventRejected(
            f"{first_name}({first['at']})와(과) {second_name}({second['at']})은(는) 같은 장소에 없다"
        )


def _apply_act(draft: State, event: Event, origin: str) -> None:
    _require_alive(draft, event["who"])
    if event.get("with"):
        _require_together(draft, event["who"], event["with"])


def _apply_move(draft: State, event: Event, origin: str) -> None:
    character = _require_alive(draft, event["who"])
    if event["to"] not in draft["locations"]:
        raise EventRejected(f"'{event['to']}' 은(는) 정의되지 않은 장소다")
    character["at"] = event["to"]


def _apply_die(draft: State, event: Event, origin: str) -> None:
    _require_alive(draft, event["who"])["alive"] = False


def _apply_give(draft: State, event: Event, origin: str) -> None:
    _require_together(draft, event["who"], event["to"])
    if draft["items"].get(event["item"]) != event["who"]:
        raise EventRejected(f"{event['who']} 은(는) '{event['item']}' 을(를) 갖고 있지 않다")
    draft["items"][event["item"]] = event["to"]


def _apply_relate(draft: State, event: Event, origin: str) -> None:
    _require_alive(draft, event["a"])
    _require_alive(draft, event["b"])
    if event["kind"] not in RELATION_KINDS:
        raise EventRejected(f"'{event['kind']}' 은(는) 정의되지 않은 관계다")
    draft["rels"][relation_key(event["a"], event["b"])] = event["kind"]


def _apply_mark(draft: State, event: Event, origin: str) -> None:
    _require_alive(draft, event["who"])
    partner = event.get("with")
    if partner and partner not in draft["chars"]:
        raise EventRejected(f"'{partner}' 은(는) 등장인물이 아니다")
    fact_name = clean_name(event.get("fact"), MAX_FACT_LENGTH)
    if not fact_name:
        raise EventRejected("성립시킬 사실의 이름이 없다")
    people = [name for name in (event["who"], partner) if name]
    # A fact that is already established keeps its first record.
    draft["facts"].setdefault(fact_name, {"people": people, "origin": origin})


_EVENT_HANDLERS: Dict[str, Callable[[State, Event, str], None]] = {
    "act": _apply_act,
    "move": _apply_move,
    "die": _apply_die,
    "give": _apply_give,
    "relate": _apply_relate,
    "mark": _apply_mark,
}


def apply_event(state: State, event: Event, origin: str = "scene") -> State:
    """Return the state after one event. Raises EventRejected and leaves the input untouched.

    origin says where the event came from (spine, choice or scene). It is recorded
    on facts the event establishes.
    """
    handler = _EVENT_HANDLERS.get(event.get("type"))
    if handler is None:
        raise EventRejected(f"정의되지 않은 사건 종류: {event.get('type')}")
    if origin not in FACT_ORIGINS:
        raise ValueError(f"unknown origin: {origin}")
    draft = copy.deepcopy(state)
    try:
        handler(draft, event, origin)
    except KeyError as missing_key:
        raise EventRejected(f"사건에 필요한 값이 없다: {missing_key}") from missing_key
    return draft


def _add_locations(draft: State, location_names: Iterable[Any]) -> None:
    for raw_name in location_names:
        name = clean_name(raw_name)
        if name and name not in draft["locations"]:
            draft["locations"].append(name)


def _add_characters(draft: State, characters: Iterable[Dict[str, Any]]) -> None:
    for character in characters:
        name = clean_name(character.get("name"))
        if not name or name in draft["chars"]:
            continue
        if character.get("at") not in draft["locations"]:
            raise EventRejected(f"새 인물 {name} 의 시작 장소 '{character.get('at')}' 은(는) 정의되지 않은 장소다")
        draft["chars"][name] = {"alive": True, "at": character["at"]}


def _add_items(draft: State, items: Iterable[Dict[str, Any]]) -> None:
    for item in items:
        name = clean_name(item.get("name"))
        if not name or name in draft["items"]:
            continue
        _require_alive(draft, item.get("holder"))
        draft["items"][name] = item["holder"]


def introduce_entities(
    state: State,
    locations: Iterable[Any] = (),
    characters: Iterable[Dict[str, Any]] = (),
    items: Iterable[Dict[str, Any]] = (),
) -> State:
    """Register locations, characters and items that appear mid-story.

    Names that already exist are ignored. Locations are added first so new
    characters can start there, and characters before items so they can hold them.
    """
    draft = copy.deepcopy(state)
    _add_locations(draft, locations)
    _add_characters(draft, characters)
    _add_items(draft, items)
    return draft


def _flatten_state(state: State) -> Dict[Any, str]:
    flat: Dict[Any, str] = {}
    for name, character in state["chars"].items():
        flat[(name, "alive")] = "alive" if character["alive"] else "dead"
        flat[(name, "location")] = character["at"]
    for item_name, holder in state["items"].items():
        flat[(item_name, "holder")] = holder
    for pair, kind in state["rels"].items():
        flat[(pair, "relation")] = kind
    for fact_name in state.get("facts") or {}:
        flat[(fact_name, "fact")] = "established"
    return flat


def diff_states(before: State, after: State) -> List[StateChange]:
    """List what differs between two states, like a code diff: only the changed cells."""
    flat_before, flat_after = _flatten_state(before), _flatten_state(after)
    changed_keys = sorted(
        key for key in flat_before.keys() | flat_after.keys() if flat_before.get(key) != flat_after.get(key)
    )
    return [
        StateChange(entity, attribute, flat_before.get((entity, attribute)), flat_after.get((entity, attribute)))
        for entity, attribute in changed_keys
    ]
