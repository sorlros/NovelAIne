import unittest
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from main import app


class HealthRoutesTest(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    def test_root_does_not_probe_database(self):
        with patch(
            "app.services.supabase_client.check_connection",
            new=AsyncMock(return_value=True),
        ) as check_connection:
            response = self.client.get("/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["version"], "0.1.0")
        self.assertNotIn("database", response.json())
        check_connection.assert_not_called()

    def test_healthz_returns_service_liveness_without_database(self):
        with patch(
            "app.services.supabase_client.check_connection",
            new=AsyncMock(return_value=True),
        ) as check_connection:
            response = self.client.get("/healthz")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"status": "ok", "service": "novelaine-backend"},
        )
        check_connection.assert_not_called()

    def test_readyz_reports_ready_when_database_is_available(self):
        with patch(
            "app.services.supabase_client.check_connection",
            new=AsyncMock(return_value=True),
        ):
            response = self.client.get("/readyz")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"status": "ready", "database": "ready"},
        )

    def test_readyz_reports_degraded_when_database_is_unavailable(self):
        with patch(
            "app.services.supabase_client.check_connection",
            new=AsyncMock(return_value=False),
        ):
            response = self.client.get("/readyz")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"status": "degraded", "database": "temporarily_unavailable"},
        )


if __name__ == "__main__":
    unittest.main()
