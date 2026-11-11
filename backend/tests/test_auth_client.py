"""Signing a user in must never happen on the shared server client.

supabase-py sends the signed-in user's token with every later query of the client it signed in
on, so a server that signs users in on its shared client acts as whoever signed in last
(RLS then hides other users' rows, and tables without a policy refuse everything).
"""
import asyncio
import os
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from app.api import auth as auth_api
from app.services import supabase_client


def session_response():
    user = SimpleNamespace(id="user-1", email="a@example.com", user_metadata={"username": "a"},
                           model_dump=lambda: {"id": "user-1"})
    return SimpleNamespace(user=user, session=SimpleNamespace(model_dump=lambda: {"access_token": "t"}))


class Recorder:
    """Records which auth methods were called on it and which tables were written."""

    def __init__(self):
        self.calls = []

        def record(name):
            def call(*_args, **_kwargs):
                self.calls.append(name)
                return session_response()
            return call

        self.auth = SimpleNamespace(**{name: record(name) for name in
                                       ("sign_up", "sign_in_with_password", "refresh_session")})

    def table(self, name):
        recorder = self

        class Query:
            def __getattr__(self, _method):
                return lambda *_args, **_kwargs: self

            def execute(self):
                recorder.calls.append(f"table:{name}")
                return SimpleNamespace(data=[])

        return Query()


class AuthUsesItsOwnClientTest(unittest.TestCase):
    def run_endpoint(self, coroutine):
        shared, throwaway = Recorder(), Recorder()
        with patch.object(auth_api, "get_supabase_client", return_value=shared), \
                patch.object(auth_api, "create_auth_client", return_value=throwaway):
            response = asyncio.run(coroutine())
        self.assertTrue(response.success, response)
        return shared.calls, throwaway.calls

    def test_signup_login_and_refresh_never_sign_in_on_the_shared_client(self):
        request = auth_api.AuthRequest(email="a@example.com", password="pw-123456", username="a")
        for endpoint, method in ((lambda: auth_api.signup(request), "sign_up"),
                                 (lambda: auth_api.login(request), "sign_in_with_password"),
                                 (lambda: auth_api.refresh_session(auth_api.RefreshRequest(refresh_token="r")),
                                  "refresh_session")):
            shared, throwaway = self.run_endpoint(endpoint)
            self.assertEqual(throwaway, [method])
            self.assertNotIn(method, shared)
            self.assertIn("table:users", shared)  # the profile is still written by the server's client

    def test_each_auth_client_is_new_and_keeps_no_session(self):
        key = "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.c2lnbmF0dXJl"
        with patch.dict(os.environ, {"SUPABASE_URL": "http://127.0.0.1:54321", "SUPABASE_KEY": key}):
            first, second = supabase_client.create_auth_client(), supabase_client.create_auth_client()
        self.assertIsNot(first, second)
        self.assertFalse(first.options.persist_session)
        self.assertFalse(first.options.auto_refresh_token)


if __name__ == "__main__":
    unittest.main()
