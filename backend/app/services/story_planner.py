"""LLM planning for skeleton-mode stories.

The model proposes; code decides. Every response is parsed defensively and
checked by story_skeleton; a problem is returned as feedback so the caller can
ask again. Nothing here touches the database.

Calls, in order of story creation:
    plan_world    seed -> world (characters, places, items, relations, premise)
    plan_spine    world -> ending, fact list and major events (written ending-first)
    repair_spine  world, events, problems -> only the events that had problems, rewritten
    plan_segment  world, state, index -> beat cards between two major events
    write_scene   brief -> prose for one scene
"""

import json
import logging
from typing import Any, Awaitable, Callable, Dict, List, Optional, Sequence, Tuple

from app.services.story_skeleton import (
    Card,
    check_segment,
    choice_changes_state,
    describe_need,
    offer_choices,
    segment_task,
    walk_cards,
)
from app.services.story_state import EVENT_TYPES, RELATION_KINDS, State, clean_name

logger = logging.getLogger(__name__)

# (system prompt, user prompt, model) -> parsed JSON object
CompleteJson = Callable[[str, str, str], Awaitable[Dict[str, Any]]]
# (system prompt, user prompt, model) -> plain text
CompleteText = Callable[[str, str, str], Awaitable[str]]

ROLES = ("protagonist", "ally", "antagonist", "neutral")
NEED_KINDS = ("alive", "at", "together", "has", "rel", "fact")
MIN_CHOICES = 3


class PlanFormatError(ValueError):
    """The model's response does not have the expected shape."""


def output_language(seed: Dict[str, Any]) -> str:
    return seed.get("language") or "ko-KR"


# ---------- prompts ----------

WORLD_SYSTEM = """You plan a long serialized novel. Design the world for the given genre, tone and protagonist. Do not write prose.

Rules:
1. Keep the protagonist's given name and give them role "protagonist". If no name is given, invent one.
2. 4 to 6 characters including the protagonist. Each one wants something that collides with what another wants. "voice" is one phrase describing how they speak.
3. 3 to 5 places with short noun names. Each character's "at" is where they are when the story starts.
4. 1 to 3 items that will matter in the story. "holder" is the character who has it.
5. "relations" are the relations when the story starts. "kind" is one of: {relations}.
6. "premise" is one sentence about what this story is about. "title" is an evocative title. "logline" is a two-sentence summary for the story list.
7. Names are unique. Write every name and every text field in {language}.

Return one JSON object:
{{"title": "", "logline": "", "premise": "", "locations": [""],
  "characters": [{{"name": "", "role": "protagonist|ally|antagonist|neutral", "wants": "", "voice": "", "at": ""}}],
  "items": [{{"name": "", "holder": ""}}],
  "relations": [{{"a": "", "b": "", "kind": ""}}]}}"""

CHANGE_RULES = """Each change is one of:
  act    "a" acts. If someone is on the other side, put that character in "b".
  move   "a" moves to place "b".
  die    "a" dies.
  give   "a" hands "item" to character "b".
  relate the relation between "a" and character "b" becomes "kind" ({relations}).
  mark   "a" establishes a fact: a secret revealed, a promise, a confession, someone learning something. Put the fact in "fact". If someone is on the other side, put them in "b".
Use null for fields a change does not use. A dead character cannot appear afterwards. Only a holder can hand an item over, and only to someone in the same place."""

SPINE_SYSTEM = """You plan a long serialized novel. Design its major events from the given world. Do not write prose.

Method: decide the ending first. Then ask what must have happened just before it for that ending to be possible, and keep walking backwards.
Write "events" in reverse order of time: start with the ending and finish with the first event of the story.

Rules:
1. The novel runs to hundreds of scenes. Major events are only the 8 to 12 turning points. Dozens of scenes are written between two major events later.
   Preparation (travel, meetings, moving items) belongs to those scenes: do not put it in "changes", state only its result in "needs".
   "when" reflects real elapsed time (day 1 is the first day). Do not schedule one event per day.
2. For each event:
   - "id" unique, starting with "e"; "title"; "meaning": one sentence on why it matters.
   - "intensity" 1 to 5. Overall it rises, and the most intense event is in the last third, but put one dip (a quiet event after a big loss) in the second half before the climax.
   - "dilemma": what the protagonist chooses between. Required when the protagonist acts in the event, otherwise "".
   - "cost": what can no longer be undone after this event. Required when intensity is 3 or more, otherwise "".
   - "changes": what happens. Each change is {{"type": "...", "a": "...", "b": ..., "item": ..., "kind": ..., "fact": ...}}.
     Changes use "type"; only needs use "pred". {change_rules}
     Turning points that are not about places, items or relations (a revealed secret, a promise) are "mark" changes.
   - "needs": what must already hold. Each is {{"pred": "...", "a": "...", "b": ..., "kind": ..., "fact": ...}} with pred one of
       alive (a is alive), at (a is at place b), together (a and character b are in the same place),
       has (a holds item b), rel (relation between a and b is kind), fact ("fact" is already established).
     An event that relies on the result of an earlier one must say so with a "fact" need.
   - "because": ids of earlier events that caused this one. Only the first event may leave it empty. Events connect by "therefore", not "and then".
   - "plants", "pays": names of foreshadowing hooks it plants and pays off. Pay off only hooks planted earlier, and pay off every hook before the end.
3. "facts" lists every fact this story establishes (6 to 12 short phrases). Every "mark" and every "fact" need must use a name from this list exactly. Establish each fact once.
4. Form (checked by code):
   - The ending has a cost: somewhere in the last third someone dies, a relation breaks (relate to {loss}), or the protagonist gives something up (give).
   - The first event is the protagonist's: they act in it (the opening scene is written from it).
   - The protagonist acts in at least half of the events. An antagonist acts first in at least one event out of five. Every ally and antagonist acts at least once.
5. Use only the characters, places and items listed. Write every text field in {language}.

Return one JSON object: {{"ending": "", "facts": [""], "events": [event, ...]}}"""

REPAIR_SYSTEM = SPINE_SYSTEM + """

You are now fixing problems in major events you already wrote.
- Rewrite only the events with problems. An event with an existing id replaces it; a new id adds an event.
- Put ids of events to delete in "remove", and new fact names in "add_facts".
- Do not repeat events that have no problem. Order is decided by "when".

Return one JSON object: {{"events": [event, ...], "remove": [""], "add_facts": [""]}}"""

SEGMENT_SYSTEM = """You plan a long serialized novel. Design the scenes that connect two major events. Do not write prose.

Rules:
1. 3 to 6 scenes. When the last one ends, every condition of the next major event must hold. Solve the listed tasks with the scenes' changes.
2. Do not write the next major event itself, only up to just before it. Do not bring forward the events listed as "not yet", and do not move their characters or items in advance.
3. Each scene has "title", "changes" (what must happen), "open" (1 or 2 parts the reader's choice may shape) and "choices" (4 or 5 candidates shown after the scene).
4. Also give "after_event_choices": 4 or 5 candidates shown right after the previous major event's scene.
5. Choices are what the reader picks for {chooser}. Every choice is something {chooser} does. "label" is one sentence.
   A choice with empty "changes" picks an attitude or tone. A choice that leaves a trace has changes:
   promising, revealing, hiding, learning or refusing is a "mark" whose "fact" is a short phrase that will be passed to later scenes;
   moving, handing over and changing a relation are "move", "give" and "relate". A choice whose only change is "act" leaves nothing behind.
   Give at least 2 of each kind. No choice may make the next major event impossible.
6. {change_rules}
   In a scene's own changes, use "mark" only for something worth remembering (a revelation, a promise between characters), at most one per scene.
7. Use only the characters, places and items listed. Write every text field in {language}.

Change shape: {{"type": "", "a": "", "b": null, "item": null, "kind": null, "fact": null}}
Return one JSON object:
{{"after_event_choices": [{{"label": "", "changes": [change]}}],
  "scenes": [{{"title": "", "changes": [change], "open": [""], "choices": [{{"label": "", "changes": [change]}}]}}]}}"""

SCENE_SYSTEM = """You are a novelist writing one scene of a long serialized novel.

Rules:
1. The brief is what is true in this world right now. Do not contradict it.
2. Everything listed under "Must happen" happens in this scene. Nothing else may change who is alive, where people are, who holds what, or how they relate.
3. "Fact" lines are established. "Reader's choice" lines are what the reader decided earlier: let them show in how characters act. "Recently" lines happened just before.
4. Characters not in the brief do not act or speak. The dead appear only in memory.
5. Plant the listed hooks without explaining them. Do not reveal where the story is heading.
6. Separate paragraphs with a blank line. Put each line of dialogue in 「」 on its own line.
7. Write about {length} characters, in {language}. Return only the prose."""


def _change_rules() -> str:
    return CHANGE_RULES.format(relations=", ".join(RELATION_KINDS))


# ---------- parsing helpers ----------


def _require_list(data: Any, key: str) -> List[Any]:
    value = data.get(key) if isinstance(data, dict) else None
    if not isinstance(value, list):
        raise PlanFormatError(f"'{key}' must be a list")
    return value


def _text(value: Any) -> str:
    return " ".join(str(value or "").split())


def _parse_change(raw: Any, locations: Sequence[str]) -> Dict[str, Any]:
    """Turn the model's flat change into an engine event."""
    if isinstance(raw, dict) and "type" not in raw and raw.get("pred") in EVENT_TYPES:
        raw = {**raw, "type": raw["pred"]}  # the need's key used for a change; the meaning is unambiguous
    if not isinstance(raw, dict) or raw.get("type") not in EVENT_TYPES:
        raise PlanFormatError(f"unknown change: {raw}")
    change_type, actor, other = raw["type"], clean_name(raw.get("a")), clean_name(raw.get("b"))
    if change_type == "act":
        # Writing a place where a character belongs means no one is on the other side.
        return {"type": "act", "who": actor, **({"with": other} if other and other not in locations else {})}
    if change_type == "move":
        return {"type": "move", "who": actor, "to": other}
    if change_type == "die":
        return {"type": "die", "who": actor}
    if change_type == "give":
        return {"type": "give", "who": actor, "to": other, "item": clean_name(raw.get("item"))}
    if change_type == "mark":
        return {"type": "mark", "who": actor, **({"with": other} if other else {}), "fact": _text(raw.get("fact"))}
    return {"type": "relate", "a": actor, "b": other, "kind": _text(raw.get("kind"))}


def _parse_need(raw: Any) -> List[Any]:
    if not isinstance(raw, dict) or raw.get("pred") not in NEED_KINDS:
        raise PlanFormatError(f"unknown need: {raw}")
    pred = raw["pred"]
    if pred == "fact":
        return [pred, _text(raw.get("fact"))]
    if pred == "alive":
        return [pred, clean_name(raw.get("a"))]
    if pred == "rel":
        return [pred, clean_name(raw.get("a")), clean_name(raw.get("b")), _text(raw.get("kind"))]
    return [pred, clean_name(raw.get("a")), clean_name(raw.get("b"))]


def _parse_spine_event(raw: Any, locations: Sequence[str]) -> Dict[str, Any]:
    if not isinstance(raw, dict) or not raw.get("id"):
        raise PlanFormatError(f"a major event has no id: {raw}")
    intensity = raw.get("intensity")
    return {
        "id": str(raw["id"]),
        "when": raw.get("when"),
        "title": _text(raw.get("title")),
        "meaning": _text(raw.get("meaning")),
        "intensity": intensity if isinstance(intensity, int) else None,
        "dilemma": _text(raw.get("dilemma")),
        "cost": _text(raw.get("cost")),
        "needs": [_parse_need(need) for need in _require_list(raw, "needs")],
        "events": [_parse_change(change, locations) for change in _require_list(raw, "changes")],
        "because": [str(cause) for cause in raw.get("because") or []],
        "plants": [_text(hook) for hook in raw.get("plants") or []],
        "pays": [_text(hook) for hook in raw.get("pays") or []],
    }


def _sorted_by_day(events: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return sorted(events, key=lambda event: event["when"] if isinstance(event.get("when"), int) else 0)


def _parse_choice(raw: Any, choice_id: str, locations: Sequence[str]) -> Dict[str, Any]:
    if not isinstance(raw, dict):
        raise PlanFormatError(f"a choice is not an object: {raw}")
    choice = {
        "id": choice_id,
        "label": _text(raw.get("label")),
        "events": [_parse_change(change, locations) for change in raw.get("changes") or []],
    }
    # The kind comes from the effect, not from what the model called it.
    return {**choice, "kind": "action" if choice_changes_state(choice) else "tone"}


# ---------- world ----------


def _parse_world(raw: Dict[str, Any], seed: Dict[str, Any]) -> Dict[str, Any]:
    characters = {}
    for character in _require_list(raw, "characters"):
        name = clean_name(character.get("name"))
        role = character.get("role") if character.get("role") in ROLES else "neutral"
        characters[name] = {"role": role, "wants": _text(character.get("wants")),
                            "voice": _text(character.get("voice")), "at": clean_name(character.get("at"))}
    protagonist = next((name for name, character in characters.items() if character["role"] == "protagonist"), None)
    return {
        "title": _text(raw.get("title")),
        "logline": _text(raw.get("logline")),
        "premise": _text(raw.get("premise")),
        "viewpoint": None if seed.get("narrative_type") == "ensemble" else protagonist,
        "locations": [clean_name(place) for place in _require_list(raw, "locations")],
        "characters": characters,
        "items": {clean_name(item.get("name")): {"holder": clean_name(item.get("holder"))}
                  for item in _require_list(raw, "items")},
        "relations": [[clean_name(rel.get("a")), clean_name(rel.get("b")), _text(rel.get("kind"))]
                      for rel in _require_list(raw, "relations")],
        "facts": [],
    }


def find_world_problems(world: Dict[str, Any], seed: Dict[str, Any], raw_count: int) -> List[str]:
    characters, places = world["characters"], world["locations"]
    problems = []
    wanted = clean_name(seed.get("protagonist_name"))
    if wanted and characters.get(wanted, {}).get("role") != "protagonist":
        problems.append(f"the protagonist must be '{wanted}'")
    if not any(character["role"] == "protagonist" for character in characters.values()):
        problems.append("no character has role 'protagonist'")
    if len(characters) != raw_count:
        problems.append("character names are not unique")
    problems += [f"{name} starts at '{c['at']}', which is not a listed place" for name, c in characters.items() if c["at"] not in places]
    problems += [f"item '{name}' is held by '{item['holder']}', who is not a character"
                 for name, item in world["items"].items() if item["holder"] not in characters]
    for first, second, kind in world["relations"]:
        problems += [f"relation names '{name}', who is not a character" for name in (first, second) if name not in characters]
        if kind not in RELATION_KINDS:
            problems.append(f"relation kind '{kind}' is not one of {', '.join(RELATION_KINDS)}")
    return problems


def _seed_text(seed: Dict[str, Any]) -> str:
    traits = ", ".join(seed.get("protagonist_traits") or [])
    lines = [f"Genre: {seed.get('genre')}", f"Tone: {seed.get('tone') or 'any'}",
             f"Narrative type: {seed.get('narrative_type') or 'hero'}",
             f"Protagonist: {seed.get('protagonist_name') or '(invent one)'} (traits: {traits or 'any'})"]
    if seed.get("protagonist_appearance_description"):
        lines.append(f"Protagonist appearance: {seed['protagonist_appearance_description']}")
    if seed.get("opening_scenario"):
        lines.append(f"Opening situation the user asked for: {seed['opening_scenario']}")
    return "\n".join(lines)


async def plan_world(
    seed: Dict[str, Any], model: str, complete: CompleteJson, feedback: Optional[str] = None
) -> Tuple[Dict[str, Any], List[str]]:
    """Return (world, problems). When there are problems, call again with them as feedback."""
    system = WORLD_SYSTEM.format(relations=", ".join(RELATION_KINDS), language=output_language(seed))
    user = _seed_text(seed) + (f"\n\nThe world you just made had these problems. Fix them: {feedback}" if feedback else "")
    raw = await complete(system, user, model)
    world = _parse_world(raw, seed)
    return world, find_world_problems(world, seed, len(_require_list(raw, "characters")))


# ---------- spine ----------


def world_text(world: Dict[str, Any]) -> str:
    lines = [f"Premise: {world['premise']}", "Places: " + ", ".join(world["locations"]), "Characters:"]
    lines += [f"- {name} ({c['role']}, starts at {c['at']}): wants {c['wants']}" for name, c in world["characters"].items()]
    lines.append("Items: " + ", ".join(f"{name} (held by {item['holder']})" for name, item in world["items"].items()))
    lines.append("Relations: " + ", ".join(f"{a}·{b} {kind}" for a, b, kind in world["relations"]))
    return "\n".join(lines)


def _spine_system(template: str, language: str) -> str:
    return template.format(change_rules=_change_rules(), loss="/".join(("enemy", "stranger")), language=language)


async def plan_spine(
    world: Dict[str, Any], seed: Dict[str, Any], model: str, complete: CompleteJson
) -> Tuple[str, List[str], List[Dict[str, Any]]]:
    """Return (ending, fact list, major events in time order). The model writes them ending-first."""
    raw = await complete(_spine_system(SPINE_SYSTEM, output_language(seed)), world_text(world), model)
    facts = [_text(fact) for fact in _require_list(raw, "facts") if _text(fact)]
    events = [_parse_spine_event(event, world["locations"]) for event in reversed(_require_list(raw, "events"))]
    return _text(raw.get("ending")), facts, _sorted_by_day(events)


def _spine_listing(events: Sequence[Dict[str, Any]]) -> str:
    return "\n".join(
        f"- {e['id']} (day {e['when']}, intensity {e['intensity']}) {e['title']} | dilemma: {e['dilemma'] or '-'} | "
        f"cost: {e['cost'] or '-'} | changes: {json.dumps(e['events'], ensure_ascii=False)} | "
        f"needs: {json.dumps(e['needs'], ensure_ascii=False)} | because: {e['because']} | plants: {e['plants']} | pays: {e['pays']}"
        for e in events
    )


async def repair_spine(
    world: Dict[str, Any], seed: Dict[str, Any], events: List[Dict[str, Any]], problems: Sequence[Tuple[str, str]],
    model: str, complete: CompleteJson,
) -> Tuple[List[str], List[Dict[str, Any]]]:
    """Ask again only for the events with problems and splice them in. Return (fact list, events)."""
    user = (f"{world_text(world)}\n\nFacts: {', '.join(world['facts']) or 'none'}\n\n"
            f"Major events (in time order):\n{_spine_listing(events)}\n\nProblems to fix:\n"
            + "\n".join(f"- {event_id}: {reason}" for event_id, reason in problems))
    raw = await complete(_spine_system(REPAIR_SYSTEM, output_language(seed)), user, model)
    facts = list(dict.fromkeys(world["facts"] + [_text(fact) for fact in raw.get("add_facts") or [] if _text(fact)]))
    fixed = {event["id"]: event for event in (_parse_spine_event(e, world["locations"]) for e in _require_list(raw, "events"))}
    removed = {str(event_id) for event_id in raw.get("remove") or []}
    kept = [fixed.pop(event["id"], event) for event in events if event["id"] not in removed or event["id"] in fixed]
    return facts, _sorted_by_day(kept + list(fixed.values()))


# ---------- segment ----------


def _state_text(state: State) -> str:
    chars = state["chars"]
    lines = ["Characters: " + ", ".join(f"{n} ({c['at'] if c['alive'] else 'dead'})" for n, c in chars.items())]
    lines.append("Items: " + ", ".join(f"{name} (held by {holder})" for name, holder in state["items"].items()))
    lines.append("Relations: " + ", ".join(f"{pair} {kind}" for pair, kind in state["rels"].items()))
    lines.append("Established facts: " + (", ".join(state.get("facts") or {}) or "none"))
    return "\n".join(lines)


def _segment_user(world: Dict[str, Any], state: State, index: int, feedback: Optional[str]) -> str:
    previous, upcoming, task = world["spine"][index - 1], world["spine"][index], segment_task(world, index)
    later = world["spine"][index + 1:index + 3]
    parts = [
        f"Premise: {world['premise']}\nPlaces: {', '.join(world['locations'])}",
        "Current state:\n" + _state_text(state),
        f"Previous major event: {previous['title']} — {previous['meaning']}",
        f"Next major event: {upcoming['title']} — {upcoming['meaning']}\nIts conditions:\n"
        + ("\n".join(f"- {describe_need(need)}" for need in upcoming["needs"]) or "- (none)"),
        "Tasks to solve:\n" + ("\n".join(f"- {describe_need(gap)}" for gap in task["gaps"]) or "- (none, just connect the flow)"),
        f"Days between the two events: {task['days']}",
        "Facts defined by the plan (use these names exactly when establishing one): " + ", ".join(world.get("facts") or []),
    ]
    if task["reintroduce"]:
        parts.append("Characters returning after a long absence (bring them back in this segment): " + ", ".join(task["reintroduce"]))
    if later:
        parts.append("Not yet (do not bring these forward):\n" + "\n".join(f"- {e['title']} — {e['meaning']}" for e in later))
    if feedback:
        parts.append(f"The scenes you just made had these problems. Fix them: {feedback}")
    return "\n\n".join(parts)


def _parse_segment(raw: Dict[str, Any], locations: Sequence[str]) -> Tuple[List[Card], List[Dict[str, Any]]]:
    cards = []
    for scene_index, scene in enumerate(_require_list(raw, "scenes"), 1):
        cards.append({
            "id": f"s{scene_index}",
            "title": _text(scene.get("title")),
            "fixed": [_parse_change(change, locations) for change in scene.get("changes") or []],
            "open": [_text(part) for part in scene.get("open") or []],
            "choices": [_parse_choice(choice, f"s{scene_index}c{n}", locations)
                        for n, choice in enumerate(scene.get("choices") or [], 1)],
        })
    after_event = [_parse_choice(choice, f"e{n}", locations) for n, choice in enumerate(_require_list(raw, "after_event_choices"), 1)]
    return cards, after_event


def _choice_problems(card_id: str, offered: Sequence[Dict[str, Any]]) -> List[Tuple[str, str]]:
    """offered comes from offer_choices, whose 'lasting' says whether the choice really changes the state."""
    problems = []
    if len(offered) < MIN_CHOICES:
        problems.append((card_id, f"only {len(offered)} choices can be offered ({MIN_CHOICES} or more needed)"))
    if not any(choice["lasting"] for choice in offered):
        problems.append((card_id, "no choice leaves a trace (a new fact, a move, a hand-over or a relation change); "
                                  "establishing a fact that already holds changes nothing"))
    if offered and all(choice["lasting"] for choice in offered):
        problems.append((card_id, "no choice is only about attitude (empty changes)"))
    return problems


def check_planned_segment(
    world: Dict[str, Any], state: State, index: int, cards: List[Card], after_event: List[Dict[str, Any]]
) -> List[Tuple[str, str]]:
    """Problems with a planned segment: cards that do not hold, an unmet next event, too few usable choices."""
    facts, target = world.get("facts"), world["spine"][index]
    errors, unmet = check_segment(state, cards, target, facts)
    problems = list(errors) + [(target["id"], f"still unmet when the segment ends: {describe_need(gap)}") for gap in unmet]
    event_card = {"id": world["spine"][index - 1]["id"], "choices": after_event}
    problems += _choice_problems(event_card["id"], offer_choices(state, event_card, cards, world["spine"][index:], facts, wanted=99))
    for position, card in enumerate(cards):
        _, after_card = walk_cards(state, cards[: position + 1], facts or ())
        offered = offer_choices(after_card, card, cards[position + 1:], world["spine"][index:], facts, wanted=99)
        problems += _choice_problems(card["id"], offered)
    return problems


async def plan_segment(
    world: Dict[str, Any], seed: Dict[str, Any], state: State, index: int, model: str, complete: CompleteJson,
    feedback: Optional[str] = None,
) -> Tuple[List[Card], List[Dict[str, Any]], List[Tuple[str, str]]]:
    """Plan the scenes before major event `index`. `state` is the state right after the previous major event.

    Returns (cards, choices shown after the previous major event's scene, problems).
    """
    chooser = world.get("viewpoint") or "the characters in the scene"
    system = SEGMENT_SYSTEM.format(chooser=chooser, change_rules=_change_rules(), language=output_language(seed))
    raw = await complete(system, _segment_user(world, state, index, feedback), model)
    cards, after_event = _parse_segment(raw, world["locations"])
    return cards, after_event, check_planned_segment(world, state, index, cards, after_event)


# ---------- prose ----------


OPENING_SCENE_LENGTH = 3000  # the first scene introduces the world, like the current first scene (about 3,500 characters)


def scene_length(intensity: Optional[int], is_opening: bool = False) -> int:
    """Short transitions, long turning points. The opening is always long."""
    if is_opening:
        return OPENING_SCENE_LENGTH
    return {1: 1200, 2: 1600, 3: 2200, 4: 2800, 5: 3200}.get(intensity or 3, 2200)


def voices_text(world: Dict[str, Any], names: Sequence[str]) -> str:
    characters = world["characters"]
    return "\n".join(f"- {name}: wants {characters[name]['wants']}; speaks {characters[name]['voice']}"
                     for name in names if name in characters)


async def write_scene(
    world: Dict[str, Any], seed: Dict[str, Any], brief: str, cast: Sequence[str], intensity: Optional[int],
    model: str, complete: CompleteText, previous_tail: str = "", is_opening: bool = False,
) -> str:
    """Write one scene from its brief. The ending is never sent."""
    system = SCENE_SYSTEM.format(length=scene_length(intensity, is_opening), language=output_language(seed))
    parts = [f"Premise: {world['premise']}", f"Brief:\n{brief}", "Characters in this scene:\n" + voices_text(world, cast)]
    if previous_tail:
        parts.append(f"The previous scene ended with:\n{previous_tail}")
    text = (await complete(system, "\n\n".join(parts), model)).strip()
    if not text:
        raise PlanFormatError("the scene is empty")
    return text

