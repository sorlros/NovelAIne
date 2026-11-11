"""Test doubles for skeleton story generation: an in-memory Supabase client and a scripted model."""

import copy
from types import SimpleNamespace
from typing import Any, Dict, List, Optional

BETRAYAL_REVEALED = "세라가 매복을 알린 사실이 드러났다"


class FakeResponse:
    def __init__(self, data=None):
        self.data = data


class FakeQuery:
    def __init__(self, client, table_name):
        self.client = client
        self.table_name = table_name
        self.filters = []
        self.operation = "select"
        self.payload = None
        self.single_result = False
        self.limit_count = None
        self.order_by = None

    def select(self, *_args):
        return self

    def eq(self, field, value):
        self.filters.append(lambda row: str(row.get(field)) == str(value))
        return self

    def is_(self, field, value):
        assert value == "null"
        self.filters.append(lambda row: row.get(field) is None)
        return self

    def in_(self, field, values):
        allowed = {str(value) for value in values}
        self.filters.append(lambda row: str(row.get(field)) in allowed)
        return self

    def order(self, field, desc=False):
        self.order_by = (field, desc)
        return self

    def limit(self, count):
        self.limit_count = count
        return self

    def range(self, start, end):
        return self

    def single(self):
        self.single_result = True
        return self

    def insert(self, payload):
        self.operation, self.payload = "insert", payload
        return self

    def update(self, payload):
        self.operation, self.payload = "update", payload
        return self

    def delete(self):
        self.operation = "delete"
        return self

    def execute(self):
        self.client.calls.append((self.table_name, self.operation))
        rows = self.client.tables.setdefault(self.table_name, [])
        if self.operation == "insert":
            return FakeResponse(self.client.insert_rows(self.table_name, self.payload))
        matched = [row for row in rows if all(test(row) for test in self.filters)]
        if self.operation == "update":
            for row in matched:
                row.update(copy.deepcopy(self.payload))
            return FakeResponse([dict(row) for row in matched])
        if self.operation == "delete":
            self.client.tables[self.table_name] = [row for row in rows if row not in matched]
            return FakeResponse(matched)
        if self.order_by:
            field, desc = self.order_by
            matched = sorted(matched, key=lambda row: row.get(field) or 0, reverse=desc)
        if self.limit_count is not None:
            matched = matched[: self.limit_count]
        if self.single_result:
            return FakeResponse(dict(matched[0]) if matched else None)
        return FakeResponse([dict(row) for row in matched])


class FakeRpc:
    """A database function call. Runs like a transaction: a failure part way leaves the tables as they were."""

    def __init__(self, client, name, params):
        self.client, self.name, self.params = client, name, params

    def execute(self):
        self.client.calls.append(("rpc", self.name))
        snapshot = copy.deepcopy(self.client.tables)
        try:
            return FakeResponse(getattr(self.client, f"rpc_{self.name}")(**copy.deepcopy(self.params)))
        except Exception:
            self.client.tables = snapshot
            raise


RUNTIME_CARD_KEYS = ("callbacks", "state_before", "previous_seq", "chosen")


class FakeClient:
    """Supports the query shapes the generation code uses, plus a unique index on story_plans.request_id."""

    def __init__(self, user_id="user-1"):
        self.auth = SimpleNamespace(get_user=lambda token: SimpleNamespace(user=SimpleNamespace(id=user_id)))
        self.tables: Dict[str, List[Dict[str, Any]]] = {}
        self.calls = []
        self.next_id = 0

    def table(self, table_name):
        return FakeQuery(self, table_name)

    def insert_rows(self, table_name, payload):
        payloads = payload if isinstance(payload, list) else [payload]
        rows = self.tables.setdefault(table_name, [])
        inserted = []
        for item in payloads:
            if table_name == "story_plans" and item.get("request_id") and any(
                row.get("request_id") == item["request_id"] for row in rows
            ):
                raise RuntimeError("duplicate key value violates unique constraint")
            self.next_id += 1
            row = {"id": f"{table_name}-{self.next_id}", **copy.deepcopy(item)}
            if table_name == "story_plans":
                row = {"lease_owner": None, "lease_until": None, "attempts": 0, "error": None, "world": None, "spine": None,
                       "retry_log": [], **row}
            rows.append(row)
            inserted.append(dict(row))
        return inserted

    def rpc(self, name, params):
        return FakeRpc(self, name, params)

    # ---------- the functions of story_play_atomic_20261111.sql, same semantics ----------

    def _beats(self, story_id):
        return [beat for beat in self.tables.setdefault("story_beats", []) if beat["story_id"] == story_id]

    def _drop_beats(self, story_id, keep):
        self.tables["story_beats"] = [b for b in self.tables.setdefault("story_beats", [])
                                      if b["story_id"] != story_id or keep(b)]

    def _stored(self, table_name, row_id):
        return next(row for row in self.tables[table_name] if row["id"] == row_id)

    def _last_sequence(self, story_id):
        return max([scene["sequence"] for scene in self.rows("scenes", story_id=story_id)] or [0])

    def rpc_save_story_turn(self, p_story_id, p_expected_seq, p_next_seq, p_world_state, p_finished, p_beat_id, p_beat,
                            p_replanned, p_user_content, p_ai_content, p_events, p_client_request_id):
        story = self.story(p_story_id)
        if not story or story.get("current_beat_seq") != p_expected_seq:
            return None
        story.update({"current_beat_seq": p_next_seq, "world_state": p_world_state})
        if p_finished:
            story["status"] = "completed"
        if p_replanned is not None:
            self._drop_beats(p_story_id, lambda b: b["seq"] <= p_expected_seq or b["spine_event_id"] is not None)
            self.insert_rows("story_beats", [{"story_id": p_story_id, "seq": row["seq"], "spine_event_id": None,
                                              "card": row["card"], "status": "planned"} for row in p_replanned])
        if p_beat_id:
            beat = next((b for b in self._beats(p_story_id) if b["id"] == p_beat_id and b["seq"] == p_next_seq), None)
            if beat is None:
                raise RuntimeError(f"beat {p_beat_id} is not beat {p_next_seq}")
            beat.update({"card": p_beat["card"], "status": "written"})
        else:
            inserted = self.insert_rows("story_beats", {"story_id": p_story_id, "seq": p_next_seq, "card": p_beat["card"],
                                                        "spine_event_id": p_beat["spine_event_id"], "status": "written"})
            beat = self._stored("story_beats", inserted[0]["id"])
        sequence = self._last_sequence(p_story_id) + 1
        user = self.insert_rows("scenes", {"story_id": p_story_id, "content": p_user_content, "sequence": sequence,
                                           "scene_type": "dialogue", "role": "user", "client_request_id": p_client_request_id})[0]
        ai = self.insert_rows("scenes", {"story_id": p_story_id, "content": p_ai_content, "sequence": sequence + 1,
                                         "scene_type": "narrative", "role": "ai", "client_request_id": p_client_request_id,
                                         "beat_id": beat["id"], "events": p_events})[0]
        beat["scene_id"] = ai["id"]
        story.update({"current_scene_id": ai["id"], "total_scenes": sequence + 1})
        return {"user_scene": user, "ai_scene": ai, "beat_id": beat["id"]}

    def rpc_undo_story_turn(self, p_story_id, p_expected_seq):
        story = self.story(p_story_id)
        if not story or story.get("current_beat_seq") != p_expected_seq:
            return False
        beat = next((b for b in self._beats(p_story_id) if b["seq"] == p_expected_seq), None)
        if not beat or "state_before" not in beat["card"]:
            return False
        card = beat["card"]  # as it was before the reset below, like v_beat in the SQL
        ai = next((scene for scene in self.rows("scenes", story_id=p_story_id) if scene["id"] == beat.get("scene_id")), None)
        if ai:
            self.tables["scenes"] = [scene for scene in self.tables["scenes"] if not (scene["story_id"] == p_story_id and (
                scene["id"] == ai["id"] or (scene["sequence"] == ai["sequence"] - 1 and scene.get("role") == "user")))]
        if beat["spine_event_id"]:
            self._drop_beats(p_story_id, lambda b: b["seq"] < beat["seq"])
        else:
            beat.update({"card": {k: v for k, v in beat["card"].items() if k not in RUNTIME_CARD_KEYS},
                         "status": "planned", "scene_id": None})
        previous = next((b for b in self._beats(p_story_id) if b["seq"] == card["previous_seq"]), None)
        story.update({"current_beat_seq": card["previous_seq"], "world_state": card["state_before"],
                      "status": "active", "current_scene_id": previous.get("scene_id") if previous else None,
                      "total_scenes": self._last_sequence(p_story_id)})
        return True

    def rpc_save_next_segment(self, p_story_id, p_beat_id, p_card, p_rows):
        story = self.story(p_story_id)
        beat = next((b for b in self._beats(p_story_id) if b["id"] == p_beat_id), None)
        if not story or not beat or story.get("current_beat_seq") != beat["seq"]:
            return False
        self._drop_beats(p_story_id, lambda b: b["seq"] <= beat["seq"])
        self.insert_rows("story_beats", [{"story_id": p_story_id, "seq": row["seq"], "spine_event_id": None,
                                          "card": row["card"], "status": "planned"} for row in p_rows])
        beat["card"] = p_card
        return True

    def rpc_replace_first_beats(self, p_story_id, p_owner, p_rows, p_lease_until):
        plan = self.plan(p_story_id)
        if not plan or plan.get("lease_owner") != p_owner:
            return False
        self._drop_beats(p_story_id, lambda b: False)
        self.insert_rows("story_beats", [{"story_id": p_story_id, "seq": row["seq"], "card": row["card"],
                                          "spine_event_id": row["spine_event_id"], "status": "planned"} for row in p_rows])
        plan.update({"step": "segment", "lease_until": p_lease_until})
        return True

    def plan(self, story_id) -> Optional[Dict[str, Any]]:
        return next((row for row in self.tables.get("story_plans", []) if row["story_id"] == story_id), None)

    def story(self, story_id) -> Optional[Dict[str, Any]]:
        return next((row for row in self.tables.get("stories", []) if row["id"] == story_id), None)

    def rows(self, table_name, **filters):
        return [row for row in self.tables.get(table_name, []) if all(row.get(k) == v for k, v in filters.items())]


# ---------- model responses in the shape the prompts ask for ----------


def change(type_, a, b=None, item=None, kind=None, fact=None):
    return {"type": type_, "a": a, "b": b, "item": item, "kind": kind, "fact": fact}


def need(pred, a, b=None, kind=None, fact=None):
    return {"pred": pred, "a": a, "b": b, "kind": kind, "fact": fact}


WORLD = {
    "title": "은빛 단검",
    "logline": "스승의 단검을 물려받은 기사가 배신을 좇는다.",
    "premise": "기사가 스승의 죽음 뒤에 숨은 배신을 좇는다.",
    "locations": ["왕성", "숲", "항구"],
    "characters": [
        {"name": "카엘", "role": "protagonist", "wants": "진실을 알고 싶다", "voice": "짧게 말한다", "at": "왕성"},
        {"name": "세라", "role": "antagonist", "wants": "자유를 원한다", "voice": "돌려 말한다", "at": "왕성"},
        {"name": "도윤", "role": "ally", "wants": "속죄하고 싶다", "voice": "느리게 말한다", "at": "숲"},
    ],
    "items": [{"name": "은빛 단검", "holder": "도윤"}],
    "relations": [{"a": "카엘", "b": "세라", "kind": "ally"}, {"a": "카엘", "b": "도윤", "kind": "ally"}],
}


def spine_event(id_, when, changes, because, intensity, needs=(), dilemma="", cost="", plants=(), pays=()):
    return {"id": id_, "when": when, "title": id_, "meaning": "…", "intensity": intensity, "dilemma": dilemma,
            "cost": cost, "changes": list(changes), "needs": list(needs), "because": list(because),
            "plants": list(plants), "pays": list(pays)}


E01 = spine_event("e01", 1, [change("act", "카엘", "세라")], [], 1, dilemma="캐물을지 넘어갈지", plants=["세라의 망설임"])
E02 = spine_event("e02", 3, [change("give", "도윤", "카엘", item="은빛 단검")], ["e01"], 2, plants=["단검의 내력"])
E03 = spine_event("e03", 4, [change("die", "도윤")], ["e02"], 4, cost="스승을 잃는다")
E04 = spine_event(
    "e04", 10,
    [change("mark", "세라", "카엘", fact=BETRAYAL_REVEALED), change("relate", "세라", "카엘", kind="enemy")],
    ["e01", "e03"], 3, needs=[need("together", "세라", "카엘")], dilemma="붙잡을지 보낼지", cost="동맹이 끝난다",
    pays=["세라의 망설임"],
)
E05 = spine_event(
    "e05", 12, [change("act", "카엘", "세라")], ["e04"], 5,
    needs=[need("at", "세라", "항구"), need("has", "카엘", "은빛 단검"), need("fact", "", fact=BETRAYAL_REVEALED)],
    dilemma="복수할지 받아들일지", cost="돌아갈 수 없다", pays=["단검의 내력"],
)
# The model writes major events ending-first.
SPINE = {"ending": "카엘은 단검을 내려놓는다.", "facts": [BETRAYAL_REVEALED], "events": [E05, E04, E03, E02, E01]}
# Same events, but the betrayal never says why: no cause, which the checks reject.
SPINE_WITH_PROBLEM = {**SPINE, "events": [E05, {**E04, "because": []}, E03, E02, E01]}
SPINE_REPAIR = {"events": [E04], "remove": [], "add_facts": []}


def tone(label):
    return {"label": label, "changes": []}


def promise(label, fact):
    return {"label": label, "changes": [change("mark", "카엘", fact=fact)]}


def choices(prefix):
    return [tone(f"{prefix} 차분하게"), tone(f"{prefix} 단호하게"),
            promise(f"{prefix} 약속한다", f"{prefix}에서 카엘이 약속했다"), promise(f"{prefix} 숨긴다", f"{prefix}에서 카엘이 숨겼다")]


SEGMENT = {
    "after_event_question": "세라의 망설임을 캐물을 것인가",
    "after_event_choices": choices("출정 전야"),
    "scenes": [
        {"title": "길을 나서다", "changes": [change("move", "카엘", "숲")], "open": ["길에서 나누는 말"],
         "question": "세라에게 무엇을 말할 것인가", "choices": choices("길")},
        {"title": "숲의 오두막", "changes": [change("act", "카엘", "도윤")], "open": ["도윤의 첫마디"],
         "question": "도윤을 믿을 것인가", "choices": choices("오두막")},
    ],
}
# The segment between e02 and e03, with its own choice wording so its facts are new.
SEGMENT2 = {
    "after_event_question": "단검을 받아 들 것인가",
    "after_event_choices": choices("단검"),
    "scenes": [
        {"title": "숲의 밤", "changes": [change("act", "카엘", "도윤")], "open": ["도윤의 옛이야기"],
         "question": "도윤의 과거를 물을 것인가", "choices": choices("밤")},
    ],
}
# The scenes never bring 카엘 to the forest, so the next major event cannot start.
SEGMENT_STUCK = {**SEGMENT, "scenes": [{**SEGMENT["scenes"][0], "changes": [change("act", "카엘")]}]}

def reading(summary, *changes, outside=False):
    """The interpreter's answer for the reader's own text."""
    return {"summary": summary, "outside": outside, "changes": list(changes)}


OPENING_PROSE = "왕성의 회랑에 바람이 들었다.\n\n「내일이면 떠나는군요.」"


class FakeModel:
    """Answers each planning call from a script keyed by the prompt it receives."""

    def __init__(self, world=WORLD, spines=(SPINE,), repairs=(SPINE_REPAIR,), segments=(SEGMENT, SEGMENT2), fail_on=None):
        self.script = {"world": [world], "spine": list(spines), "repair": list(repairs), "segment": list(segments),
                       "interpret": [reading("카엘이 세라를 바라본다")]}
        self.calls: List[tuple] = []
        self.fail_on = fail_on or {}

    @staticmethod
    def kind_of(system: str) -> str:
        if "직접 쓴 글을" in system:
            return "interpret"
        if "문제를 고치는 단계" in system:
            return "repair"
        if "주요 사건을 설계" in system:
            return "spine"
        if "두 주요 사건 사이를 잇는" in system:
            return "segment"
        return "world"

    async def complete_json(self, system, user, model):
        kind = self.kind_of(system)
        self.calls.append((kind, model, user))
        if kind in self.fail_on:
            raise self.fail_on[kind]
        answers = self.script[kind]
        return copy.deepcopy(answers.pop(0) if len(answers) > 1 else answers[0])

    async def complete_text(self, system, user, model):
        self.calls.append(("scene", model, user))
        if "scene" in self.fail_on:
            raise self.fail_on["scene"]
        return OPENING_PROSE

    async def stream_text(self, system, user, model):
        self.calls.append(("stream", model, user))
        if "stream" in self.fail_on:
            raise self.fail_on["stream"]
        for piece in self.stream_pieces:
            yield piece

    stream_pieces = ("숲길에 바람이 불었다.", "\n\n「가자.」")

    def kinds(self):
        return [kind for kind, _, _ in self.calls]


def story_request(**overrides):
    from app.schemas.models import StoryCreate

    fields = {"genre": "fantasy", "tone": "진지하고 무거운", "protagonist_name": "카엘",
              "protagonist_traits": ["용감한"], "language": "ko-KR", "request_id": "req-1"}
    return StoryCreate(**{**fields, **overrides})
