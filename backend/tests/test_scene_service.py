import unittest

from app.services.scene_service import (
    find_chat_turn_by_client_request_id,
    persist_chat_turn,
)


class FakeResponse:
    def __init__(self, data):
        self.data = data


class FakeQuery:
    def __init__(self, client, table_name):
        self.client = client
        self.table_name = table_name
        self.filters = []
        self.order_field = None
        self.order_desc = False
        self.limit_count = None
        self.operation = "select"
        self.payload = None

    def select(self, *_args):
        self.operation = "select"
        return self

    def eq(self, field, value):
        self.filters.append((field, value))
        return self

    def order(self, field, desc=False):
        self.order_field = field
        self.order_desc = desc
        return self

    def limit(self, count):
        self.limit_count = count
        return self

    def insert(self, payload):
        self.operation = "insert"
        self.payload = payload
        return self

    def update(self, payload):
        self.operation = "update"
        self.payload = payload
        return self

    def execute(self):
        rows = self.client.tables.setdefault(self.table_name, [])
        if self.operation == "insert":
            row = dict(self.payload)
            row.setdefault("id", f"{self.table_name}-{len(rows) + 1}")
            rows.append(row)
            return FakeResponse([row])

        if self.operation == "update":
            matched = []
            for row in rows:
                if self._matches(row):
                    row.update(self.payload)
                    matched.append(row)
            return FakeResponse(matched)

        selected = [row for row in rows if self._matches(row)]
        if self.order_field is not None:
            selected.sort(
                key=lambda row: row.get(self.order_field) or 0,
                reverse=self.order_desc,
            )
        if self.limit_count is not None:
            selected = selected[: self.limit_count]
        return FakeResponse(selected)

    def _matches(self, row):
        return all(str(row.get(field)) == str(value) for field, value in self.filters)


class FakeClient:
    def __init__(self):
        self.tables = {"scenes": [], "stories": [{"id": "story-1"}]}

    def table(self, table_name):
        return FakeQuery(self, table_name)


class SceneServiceIdempotencyTest(unittest.TestCase):
    def test_persist_chat_turn_reuses_existing_client_request(self):
        client = FakeClient()

        first = persist_chat_turn(
            client,
            "story-1",
            user_message="open the gate",
            ai_message="the gate opens",
            client_request_id="request-1",
        )
        second = persist_chat_turn(
            client,
            "story-1",
            user_message="open the gate",
            ai_message="different retry response",
            client_request_id="request-1",
        )

        self.assertFalse(first["deduplicated"])
        self.assertTrue(second["deduplicated"])
        self.assertEqual(len(client.tables["scenes"]), 2)
        self.assertEqual(second["ai_scene"]["content"], "the gate opens")
        self.assertEqual(second["user_scene"]["role"], "user")
        self.assertEqual(second["ai_scene"]["role"], "ai")

    def test_persist_chat_turn_without_client_request_is_not_deduplicated(self):
        client = FakeClient()

        persist_chat_turn(
            client,
            "story-1",
            user_message="first",
            ai_message="first response",
        )
        persist_chat_turn(
            client,
            "story-1",
            user_message="first",
            ai_message="first response",
        )

        self.assertEqual(len(client.tables["scenes"]), 4)
        self.assertEqual([row["sequence"] for row in client.tables["scenes"]], [1, 2, 3, 4])

    def test_find_chat_turn_requires_user_and_ai_scene(self):
        client = FakeClient()
        client.tables["scenes"].append(
            {
                "id": "scenes-1",
                "story_id": "story-1",
                "role": "user",
                "sequence": 1,
                "client_request_id": "request-2",
            }
        )

        found = find_chat_turn_by_client_request_id(client, "story-1", "request-2")

        self.assertIsNone(found)


if __name__ == "__main__":
    unittest.main()
