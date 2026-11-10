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

Prompts are Korean. JSON keys and enum values (type, pred, role, kind) stay
English because code reads them.
"""

import json
import logging
from typing import Any, AsyncIterator, Awaitable, Callable, Dict, List, Optional, Sequence, Tuple

from app.services.story_skeleton import (
    CHOICE,
    Card,
    check_segment,
    choice_changes_state,
    describe_need,
    fact_tier,
    offer_choices,
    segment_task,
    walk_cards,
)
from app.services.story_state import EVENT_TYPES, RELATION_KINDS, RELATION_LABELS, State, clean_name

logger = logging.getLogger(__name__)

# (system prompt, user prompt, model) -> parsed JSON object
CompleteJson = Callable[[str, str, str], Awaitable[Dict[str, Any]]]
# (system prompt, user prompt, model) -> plain text
CompleteText = Callable[[str, str, str], Awaitable[str]]
# (system prompt, user prompt, model) -> plain text, piece by piece
CompleteStream = Callable[[str, str, str], AsyncIterator[str]]

ROLES = ("protagonist", "ally", "antagonist", "neutral")
NEED_KINDS = ("alive", "at", "together", "has", "rel", "fact")
MIN_CHOICES = 3
LANGUAGE_NAMES = {"ko": "한국어", "en": "영어", "ja": "일본어", "zh": "중국어"}
RECALLED_CHOICES = 6  # how many of the reader's earlier choices the segment planner sees


class PlanFormatError(ValueError):
    """The model's response does not have the expected shape."""


def output_language(seed: Dict[str, Any]) -> str:
    """The language the story is written in, named for the prompts (ko-KR -> 한국어)."""
    code = seed.get("language") or "ko-KR"
    return LANGUAGE_NAMES.get(code.replace("_", "-").split("-")[0].lower(), code)


# ---------- prompts ----------

WORLD_SYSTEM = """당신은 긴 연재소설의 기획자다. 주어진 장르, 분위기, 주인공으로 이야기의 세계를 설계한다. 본문은 쓰지 않는다.

규칙:
1. 주인공은 주어진 이름을 그대로 쓰고 role 을 "protagonist" 로 한다. 이름이 주어지지 않았으면 짓는다.
2. 인물은 주인공을 포함해 4~6명이다. 각자 원하는 것(wants)이 다른 인물이 원하는 것과 부딪히게 만든다. voice 는 그 인물의 말투를 한 구절로 쓴다.
3. 장소는 3~5곳이고 짧은 명사로 짓는다. 인물의 at 은 이야기가 시작할 때 그 인물이 있는 장소다.
4. 물건은 이야기에서 역할을 할 것만 1~3개 둔다. holder 는 그 물건을 가진 인물이다.
5. relations 는 이야기가 시작할 때의 관계다. kind 는 다음 가운데 하나다: {relations}
6. premise 는 이 이야기가 무엇에 관한 것인지 한 문장으로 쓴다. title 은 인상적인 제목, logline 은 이야기 목록에 보일 두 문장 요약이다.
7. 이름은 서로 겹치지 않는다. 모든 이름과 글은 {language}로 쓴다.

JSON 객체 하나를 돌려준다:
{{"title": "", "logline": "", "premise": "", "locations": [""],
  "characters": [{{"name": "", "role": "protagonist|ally|antagonist|neutral", "wants": "", "voice": "", "at": ""}}],
  "items": [{{"name": "", "holder": ""}}],
  "relations": [{{"a": "", "b": "", "kind": ""}}]}}"""

CHANGE_RULES = """변화(change)는 다음 가운데 하나다. 형태: {{"type": "", "a": "", "b": null, "item": null, "kind": null, "fact": null}}
  act    a 가 행동한다. 상대가 있으면 그 인물을 b 에 적는다.
  move   a 가 장소 b 로 이동한다.
  die    a 가 죽는다.
  give   a 가 인물 b 에게 item 을 건넨다.
  relate a 와 인물 b 의 관계가 kind({relations})로 바뀐다.
  mark   a 가 사실 하나를 성립시킨다: 드러난 비밀, 약속, 고백, 누군가 무언가를 알게 됨. 그 사실을 fact 에 짧은 구절로 적고, 상대가 있으면 b 에 적는다.
쓰지 않는 칸은 null 로 둔다. 변화는 "type" 을 쓰고, "pred" 는 조건(needs)에만 쓴다.
죽은 인물은 그 뒤에 나올 수 없다. 물건은 가진 인물만, 같은 장소에 있는 인물에게만 건넬 수 있다."""

SPINE_SYSTEM = """당신은 긴 연재소설의 기획자다. 주어진 세계로 이야기의 주요 사건을 설계한다. 본문은 쓰지 않는다.

방법: 결말을 먼저 정한다. 그 결말이 가능하려면 바로 앞에 무엇이 일어났어야 하는지를 물으며 거꾸로 올라간다.
events 는 시간의 역순으로 적는다. 결말에서 시작해 이야기의 첫 사건으로 끝난다.

규칙:
1. 이 소설은 수백 장면에 이른다. 주요 사건은 그 가운데 이야기의 방향을 바꾸는 전환점 8~12개뿐이다. 두 주요 사건 사이의 수십 장면은 나중에 따로 쓴다.
   전환점에 이르는 준비(이동, 만남, 물건 옮기기)는 그 장면들의 몫이다. changes 에 넣지 말고 그 결과만 needs 에 적는다.
   when 은 실제로 흐른 시간을 반영한다(이야기의 첫날이 1). 사건을 하루에 하나씩 놓지 않는다.
2. 사건마다 적는 것:
   - id: e 로 시작하는 고유한 이름. title. meaning: 이 사건이 왜 중요한지 한 문장.
   - intensity: 1~5. 전체적으로 오르고 가장 높은 사건은 마지막 3분의 1에 둔다. 다만 후반부, 절정 앞에 한 번 꺾이는 사건(크게 잃은 뒤의 가라앉음)을 둔다.
   - dilemma: 주인공이 무엇과 무엇 사이에서 고르는지. 주인공이 행동하는 사건에는 반드시 적고, 그 밖에는 "".
   - cost: 이 사건 뒤로 되돌릴 수 없게 된 것. intensity 가 3 이상이면 반드시 적고, 그 밖에는 "".
   - changes: 일어나는 일. {change_rules}
     장소·물건·관계로 적을 수 없는 전환점(드러난 비밀, 약속)은 mark 로 적는다.
   - needs: 이미 갖춰져 있어야 하는 것. 형태: {{"pred": "", "a": "", "b": null, "kind": null, "fact": null}}. pred 는 다음 가운데 하나다.
       alive(a 가 살아 있다), at(a 가 장소 b 에 있다), together(a 와 인물 b 가 같은 장소에 있다),
       has(a 가 물건 b 를 갖고 있다), rel(a 와 b 의 관계가 kind 다), fact(fact 가 이미 성립해 있다).
     앞선 사건의 결과에 기대는 사건은 반드시 fact 조건으로 적는다.
   - because: 이 사건을 일으킨, 시간상 앞선 사건의 id. 첫 사건만 비울 수 있다. 사건들은 "그리고"가 아니라 "그래서"로 이어진다.
   - plants, pays: 이 사건이 심는 복선과 회수하는 복선의 이름. 앞서 심은 복선만 회수하고, 심은 복선은 끝나기 전에 모두 회수한다.
3. facts 에는 이 이야기에서 성립하는 사실을 모두 적는다(짧은 구절 6~12개). mark 의 fact 와 needs 의 fact 는 이 목록의 이름과 글자 하나까지 같아야 한다. 한 사실은 한 번만 성립시킨다.
4. 짜임새(코드가 검사한다):
   - 결말에는 대가가 있다. 마지막 3분의 1 어딘가에서 누군가 죽거나, 관계가 끊기거나(relate 로 {loss}), 주인공이 무언가를 내놓는다(give).
   - 첫 사건은 주인공의 것이다. 주인공이 그 사건에서 행동한다(첫 장면이 이 사건으로 쓰인다).
   - 주인공은 사건의 절반 이상에서 행동한다. 적대자는 사건 다섯 개마다 하나 이상에서 먼저 움직인다. 조력자와 적대자는 각자 한 번 이상 행동한다.
5. 목록에 있는 인물, 장소, 물건만 쓴다. 모든 글은 {language}로 쓴다.

JSON 객체 하나를 돌려준다: {{"ending": "", "facts": [""], "events": [사건, ...]}}"""

REPAIR_SYSTEM = SPINE_SYSTEM + """

지금은 이미 쓴 주요 사건의 문제를 고치는 단계다.
- 문제가 있는 사건만 다시 쓴다. 이미 있는 id 로 쓰면 그 사건을 바꾸고, 새 id 로 쓰면 사건을 더한다.
- 지울 사건의 id 는 remove 에, 새로 필요한 사실의 이름은 add_facts 에 적는다.
- 문제가 없는 사건은 다시 적지 않는다. 순서는 when 으로 정해진다.

JSON 객체 하나를 돌려준다: {{"events": [사건, ...], "remove": [""], "add_facts": [""]}}"""

SEGMENT_SYSTEM = """당신은 긴 연재소설의 기획자다. 두 주요 사건 사이를 잇는 장면들을 설계한다. 본문은 쓰지 않는다.

규칙:
1. 장면은 3~6개다. 마지막 장면이 끝났을 때 다음 주요 사건의 조건이 모두 갖춰져 있어야 한다. '풀어야 할 과제'를 장면의 changes 로 푼다.
2. 다음 주요 사건 자체는 쓰지 않고 그 직전까지만 쓴다. '아직 일어나면 안 되는 일'을 앞당기지 않고, 그 인물이나 물건을 미리 움직여 두지도 않는다.
3. 장면마다 title, changes(반드시 일어나는 일), open(독자의 선택이 바꿀 수 있는 부분 1~2개), question, choices(장면 뒤에 보일 후보 4~5개)를 적는다.
   question 은 이 장면이 끝날 때 독자에게 던지는 질문 하나다. 장면의 딜레마나 열린 부분에서 나온다.
4. after_event_question 과 after_event_choices(4~5개)도 적는다. 바로 앞 주요 사건의 장면이 끝난 직후의 질문과 선택지다.
5. 선택지는 독자가 {chooser}에 대해 고르는 것이다. 모든 선택지는 {chooser}이(가) 하는 일이다. label 은 한 문장이다.
   - 한 장면의 선택지는 모두 그 장면의 question 에 대한 서로 다른 답이다. 서로 무관한 행동을 나열하지 않는다.
   - 장면마다 적어도 하나는 다른 인물을 이름으로 끌어들이고, 그 인물이 원하는 것이 걸린 선택지로 만든다.
   - '독자가 앞서 고른 것'이 있으면, 이 구간의 선택지 가운데 적어도 하나는 그중 하나를 지키거나 어기는 선택지로 만든다.
   - changes 가 빈 선택지는 태도나 말투를 고르는 것이다. 뒤에 흔적을 남기는 선택지는 changes 를 가진다:
     약속하기, 밝히기, 숨기기, 알아내기, 거절하기는 mark 이고 fact 는 뒤 장면에 전달될 짧은 구절이다.
     이동, 건네기, 관계 바꾸기는 move, give, relate 다. changes 가 act 뿐인 선택지는 아무것도 남기지 않는다.
     이미 성립한 사실을 다시 성립시키는 선택지도 아무것도 남기지 않는다.
   - 두 종류를 각각 2개 이상 넣는다. 다음 주요 사건을 불가능하게 만드는 선택지는 넣지 않는다.
6. {change_rules}
   장면 자체의 changes 에서 mark 는 기억할 만한 일(드러난 비밀, 인물 사이의 약속)에만, 장면당 하나까지 쓴다.
7. 목록에 있는 인물, 장소, 물건만 쓴다. 모든 글은 {language}로 쓴다.

JSON 객체 하나를 돌려준다:
{{"after_event_question": "", "after_event_choices": [{{"label": "", "changes": [변화]}}],
  "scenes": [{{"title": "", "changes": [변화], "open": [""], "question": "", "choices": [{{"label": "", "changes": [변화]}}]}}]}}"""

SCENE_SYSTEM = """당신은 긴 연재소설의 한 장면을 쓰는 소설가다.

규칙:
1. 지시서는 지금 이 세계에서 참인 것이다. 어긋나게 쓰지 않는다.
2. '반드시' 줄의 일은 이 장면에서 일어난다. 그 밖의 일로 누가 살아 있는지, 어디에 있는지, 무엇을 가졌는지, 어떤 관계인지가 바뀌면 안 된다.
3. '사실' 줄은 성립한 사실이다. '독자의 선택' 줄은 독자가 앞서 고른 것이니 인물의 행동과 말에 드러나게 한다. '최근의 일' 줄은 직전에 있었던 일이다.
4. 지시서에 없는 인물은 행동하거나 말하지 않는다. 죽은 인물은 기억으로만 나온다.
5. 복선은 설명하지 말고 심어 둔다. 이야기가 어디로 가는지 드러내지 않는다.
6. '독자에게 묻는 것'이 있으면 장면을 그 질문 앞에서 멈춘다. 답을 대신 정하지 않는다.
7. 문단은 빈 줄로 나눈다. 대사는 「」로 감싸 한 줄에 하나씩 쓴다.
8. 약 {length}자 분량으로, {language}로 쓴다. 본문만 돌려준다."""


def _relation_choices() -> str:
    return ", ".join(f"{kind}({RELATION_LABELS[kind]})" for kind in RELATION_KINDS)


def _change_rules() -> str:
    return CHANGE_RULES.format(relations=_relation_choices())


# ---------- parsing helpers ----------


def _require_list(data: Any, key: str) -> List[Any]:
    value = data.get(key) if isinstance(data, dict) else None
    if not isinstance(value, list):
        raise PlanFormatError(f"'{key}' 은(는) 목록이어야 한다")
    return value


def _text(value: Any) -> str:
    return " ".join(str(value or "").split())


def _texts(value: Any) -> List[str]:
    """A list of short texts. One text written as a plain string counts as a list of one, not as its letters."""
    items = [value] if isinstance(value, str) else value if isinstance(value, list) else []
    return [text for text in (_text(item) for item in items) if text]


def _parse_change(raw: Any, locations: Sequence[str]) -> Dict[str, Any]:
    """Turn the model's flat change into an engine event."""
    if isinstance(raw, dict) and "type" not in raw and raw.get("pred") in EVENT_TYPES:
        raw = {**raw, "type": raw["pred"]}  # the need's key used for a change; the meaning is unambiguous
    if not isinstance(raw, dict) or raw.get("type") not in EVENT_TYPES:
        raise PlanFormatError(f"알 수 없는 변화: {raw}")
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
        raise PlanFormatError(f"알 수 없는 조건: {raw}")
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
        raise PlanFormatError(f"id 가 없는 주요 사건: {raw}")
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
        "because": _texts(raw.get("because")),
        "plants": _texts(raw.get("plants")),
        "pays": _texts(raw.get("pays")),
    }


def _sorted_by_day(events: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return sorted(events, key=lambda event: event["when"] if isinstance(event.get("when"), int) else 0)


def _parse_choice(raw: Any, choice_id: str, locations: Sequence[str]) -> Dict[str, Any]:
    if not isinstance(raw, dict):
        raise PlanFormatError(f"선택지가 객체가 아니다: {raw}")
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
        problems.append(f"주인공은 '{wanted}' 이어야 한다")
    if not any(character["role"] == "protagonist" for character in characters.values()):
        problems.append("role 이 protagonist 인 인물이 없다")
    if len(characters) != raw_count:
        problems.append("인물 이름이 겹친다")
    problems += [f"{name} 의 시작 장소 '{c['at']}' 이(가) 장소 목록에 없다" for name, c in characters.items() if c["at"] not in places]
    problems += [f"물건 '{name}' 의 소지자 '{item['holder']}' 이(가) 인물 목록에 없다"
                 for name, item in world["items"].items() if item["holder"] not in characters]
    for first, second, kind in world["relations"]:
        problems += [f"관계에 나온 '{name}' 이(가) 인물 목록에 없다" for name in (first, second) if name not in characters]
        if kind not in RELATION_KINDS:
            problems.append(f"관계 종류 '{kind}' 은(는) {', '.join(RELATION_KINDS)} 가운데 하나여야 한다")
    return problems


def _seed_text(seed: Dict[str, Any]) -> str:
    traits = ", ".join(seed.get("protagonist_traits") or [])
    narrative = "군상극(특정 주인공 없이 여러 인물)" if seed.get("narrative_type") == "ensemble" else "주인공 중심"
    lines = [f"장르: {seed.get('genre')}", f"분위기: {seed.get('tone') or '자유'}", f"서사 유형: {narrative}",
             f"주인공: {seed.get('protagonist_name') or '(지어서 정한다)'} (성격: {traits or '자유'})"]
    if seed.get("protagonist_appearance_description"):
        lines.append(f"주인공의 외형: {seed['protagonist_appearance_description']}")
    if seed.get("opening_scenario"):
        lines.append(f"유저가 원한 시작 상황: {seed['opening_scenario']}")
    return "\n".join(lines)


async def plan_world(
    seed: Dict[str, Any], model: str, complete: CompleteJson, feedback: Optional[str] = None
) -> Tuple[Dict[str, Any], List[str]]:
    """Return (world, problems). When there are problems, call again with them as feedback."""
    system = WORLD_SYSTEM.format(relations=_relation_choices(), language=output_language(seed))
    user = _seed_text(seed) + (f"\n\n방금 만든 세계에 다음 문제가 있었다. 고쳐서 다시 만든다: {feedback}" if feedback else "")
    raw = await complete(system, user, model)
    world = _parse_world(raw, seed)
    return world, find_world_problems(world, seed, len(_require_list(raw, "characters")))


# ---------- spine ----------


def world_text(world: Dict[str, Any]) -> str:
    lines = [f"전제: {world['premise']}", "장소: " + ", ".join(world["locations"]), "인물:"]
    lines += [f"- {name} ({c['role']}, 시작 장소 {c['at']}): 원하는 것 — {c['wants']}" for name, c in world["characters"].items()]
    lines.append("물건: " + ", ".join(f"{name}(소지자 {item['holder']})" for name, item in world["items"].items()))
    lines.append("관계: " + ", ".join(f"{a}·{b} {RELATION_LABELS.get(kind, kind)}" for a, b, kind in world["relations"]))
    return "\n".join(lines)


def _spine_system(template: str, language: str) -> str:
    loss = "/".join(f"{kind}({RELATION_LABELS[kind]})" for kind in ("enemy", "stranger"))
    return template.format(change_rules=_change_rules(), loss=loss, language=language)


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
        f"- {e['id']} ({e['when']}일, 강도 {e['intensity']}) {e['title']} | 딜레마: {e['dilemma'] or '-'} | "
        f"대가: {e['cost'] or '-'} | changes: {json.dumps(e['events'], ensure_ascii=False)} | "
        f"needs: {json.dumps(e['needs'], ensure_ascii=False)} | because: {e['because']} | plants: {e['plants']} | pays: {e['pays']}"
        for e in events
    )


async def repair_spine(
    world: Dict[str, Any], seed: Dict[str, Any], events: List[Dict[str, Any]], problems: Sequence[Tuple[str, str]],
    model: str, complete: CompleteJson,
) -> Tuple[List[str], List[Dict[str, Any]]]:
    """Ask again only for the events with problems and splice them in. Return (fact list, events)."""
    user = (f"{world_text(world)}\n\n사실 목록: {', '.join(world['facts']) or '없음'}\n\n"
            f"주요 사건(시간순):\n{_spine_listing(events)}\n\n고쳐야 할 문제:\n"
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
    lines = ["인물: " + ", ".join(f"{n}({c['at'] if c['alive'] else '사망'})" for n, c in chars.items())]
    lines.append("물건: " + ", ".join(f"{name}(소지자 {holder})" for name, holder in state["items"].items()))
    lines.append("관계: " + ", ".join(f"{pair} {RELATION_LABELS.get(kind, kind)}" for pair, kind in state["rels"].items()))
    lines.append("성립한 사실: " + (", ".join(state.get("facts") or {}) or "없음"))
    return "\n".join(lines)


def recalled_choices(world: Dict[str, Any], state: State) -> List[str]:
    """The reader's earlier choices that left a fact, oldest first, for the planner to call back."""
    facts = state.get("facts") or {}
    chosen = [name for name, record in facts.items() if fact_tier(name, record, world.get("facts") or ()) == CHOICE]
    return chosen[-RECALLED_CHOICES:]


def _wants_text(world: Dict[str, Any], state: State) -> str:
    living = [name for name, character in state["chars"].items() if character["alive"]]
    return "\n".join(f"- {name}: {world['characters'][name]['wants']}" for name in living if name in world["characters"])


def _segment_user(world: Dict[str, Any], state: State, index: int, feedback: Optional[str]) -> str:
    previous, upcoming, task = world["spine"][index - 1], world["spine"][index], segment_task(world, index)
    later, recalled = world["spine"][index + 1:index + 3], recalled_choices(world, state)
    parts = [
        f"전제: {world['premise']}\n장소: {', '.join(world['locations'])}",
        "지금 상태:\n" + _state_text(state),
        "인물이 원하는 것:\n" + _wants_text(world, state),
        f"바로 앞 주요 사건: {previous['title']} — {previous['meaning']}",
        f"다음 주요 사건: {upcoming['title']} — {upcoming['meaning']}\n그 사건의 조건:\n"
        + ("\n".join(f"- {describe_need(need)}" for need in upcoming["needs"]) or "- (없음)"),
        "풀어야 할 과제:\n" + ("\n".join(f"- {describe_need(gap)}" for gap in task["gaps"]) or "- (없음. 흐름만 잇는다)"),
        f"두 사건 사이에 흐르는 시간: {task['days']}일",
        "뼈대가 정한 사실(이 가운데 하나를 성립시킬 때는 이름을 그대로 쓴다): " + ", ".join(world.get("facts") or []),
    ]
    if recalled:
        parts.append("독자가 앞서 고른 것(지키거나 어기는 선택지를 만든다):\n" + "\n".join(f"- {name}" for name in recalled))
    if task["reintroduce"]:
        parts.append("오랜만에 나오는 인물(이 구간에서 다시 등장시킨다): " + ", ".join(task["reintroduce"]))
    if later:
        parts.append("아직 일어나면 안 되는 일:\n" + "\n".join(f"- {e['title']} — {e['meaning']}" for e in later))
    if feedback:
        parts.append(f"방금 만든 장면들에 다음 문제가 있었다. 고쳐서 다시 만든다: {feedback}")
    return "\n\n".join(parts)


def _parse_segment(raw: Dict[str, Any], locations: Sequence[str]) -> Tuple[List[Card], Dict[str, Any]]:
    cards = []
    for scene_index, scene in enumerate(_require_list(raw, "scenes"), 1):
        cards.append({
            "id": f"s{scene_index}",
            "title": _text(scene.get("title")),
            "fixed": [_parse_change(change, locations) for change in scene.get("changes") or []],
            "open": [_text(part) for part in scene.get("open") or []],
            "question": _text(scene.get("question")),
            "choices": [_parse_choice(choice, f"s{scene_index}c{n}", locations)
                        for n, choice in enumerate(scene.get("choices") or [], 1)],
        })
    after_event = {
        "question": _text(raw.get("after_event_question")),
        "choices": [_parse_choice(choice, f"e{n}", locations) for n, choice in enumerate(_require_list(raw, "after_event_choices"), 1)],
    }
    return cards, after_event


def _choice_problems(card_id: str, offered: Sequence[Dict[str, Any]]) -> List[Tuple[str, str]]:
    """offered comes from offer_choices, whose 'lasting' says whether the choice really changes the state."""
    problems = []
    if len(offered) < MIN_CHOICES:
        problems.append((card_id, f"내놓을 수 있는 선택지가 {len(offered)}개뿐이다({MIN_CHOICES}개 이상 필요)"))
    if not any(choice["lasting"] for choice in offered):
        problems.append((card_id, "뒤에 흔적을 남기는 선택지(새 사실, 이동, 건네기, 관계 변화)가 없다. 이미 성립한 사실을 다시 성립시키는 것은 흔적이 아니다"))
    if offered and all(choice["lasting"] for choice in offered):
        problems.append((card_id, "태도만 고르는 선택지(changes 가 빈 것)가 없다"))
    return problems


def check_planned_segment(
    world: Dict[str, Any], state: State, index: int, cards: List[Card], after_event: Dict[str, Any]
) -> List[Tuple[str, str]]:
    """Problems with a planned segment: cards that do not hold, an unmet next event, too few usable choices."""
    facts, target = world.get("facts"), world["spine"][index]
    errors, unmet = check_segment(state, cards, target, facts)
    problems = list(errors) + [(target["id"], f"구간이 끝나도 갖춰지지 않는다: {describe_need(gap)}") for gap in unmet]
    event_card = {"id": world["spine"][index - 1]["id"], "choices": after_event["choices"]}
    problems += _choice_problems(event_card["id"], offer_choices(state, event_card, cards, world["spine"][index:], facts, wanted=99))
    for position, card in enumerate(cards):
        _, after_card = walk_cards(state, cards[: position + 1], facts or ())
        offered = offer_choices(after_card, card, cards[position + 1:], world["spine"][index:], facts, wanted=99)
        problems += _choice_problems(card["id"], offered)
    return problems


async def plan_segment(
    world: Dict[str, Any], seed: Dict[str, Any], state: State, index: int, model: str, complete: CompleteJson,
    feedback: Optional[str] = None,
) -> Tuple[List[Card], Dict[str, Any], List[Tuple[str, str]]]:
    """Plan the scenes before major event `index`. `state` is the state right after the previous major event.

    Returns (cards, {"question", "choices"} shown after the previous major event's scene, problems).
    """
    chooser = world.get("viewpoint") or "장면 속 인물들"
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
    return "\n".join(f"- {name}: 원하는 것 — {characters[name]['wants']}; 말투 — {characters[name]['voice']}"
                     for name in names if name in characters)


def scene_prompt(
    world: Dict[str, Any], seed: Dict[str, Any], brief: str, cast: Sequence[str], intensity: Optional[int],
    previous_tail: str = "", is_opening: bool = False,
) -> Tuple[str, str]:
    """(system, user) for writing one scene from its brief. The ending is never included."""
    system = SCENE_SYSTEM.format(length=scene_length(intensity, is_opening), language=output_language(seed))
    parts = [f"전제: {world['premise']}", f"지시서:\n{brief}", "이 장면의 인물:\n" + voices_text(world, cast)]
    if previous_tail:
        parts.append(f"앞 장면은 이렇게 끝났다:\n{previous_tail}")
    return system, "\n\n".join(parts)


async def write_scene(
    world: Dict[str, Any], seed: Dict[str, Any], brief: str, cast: Sequence[str], intensity: Optional[int],
    model: str, complete: CompleteText, previous_tail: str = "", is_opening: bool = False,
) -> str:
    """Write one scene from its brief and return it whole."""
    system, user = scene_prompt(world, seed, brief, cast, intensity, previous_tail, is_opening)
    text = (await complete(system, user, model)).strip()
    if not text:
        raise PlanFormatError("장면 본문이 비어 있다")
    return text
