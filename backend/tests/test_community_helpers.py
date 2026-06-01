import unittest

from app.api.community import _moderation_status_for_report_count, _normalise_comment


class CommunityHelpersTest(unittest.TestCase):
    def test_report_threshold_hides_comment_after_three_reports(self):
        self.assertEqual(_moderation_status_for_report_count(0), "visible")
        self.assertEqual(_moderation_status_for_report_count(2), "visible")
        self.assertEqual(_moderation_status_for_report_count(3), "hidden")
        self.assertEqual(_moderation_status_for_report_count(5), "hidden")

    def test_normalise_comment_defaults_moderation_fields(self):
        comment = _normalise_comment(
            {
                "id": "comment-1",
                "story_id": "story-1",
                "user_id": "user-1",
                "content": "hello",
                "created_at": "2026-06-01T00:00:00Z",
                "updated_at": "2026-06-01T00:00:00Z",
                "users": {"username": "Writer", "avatar_url": None},
            }
        )

        self.assertEqual(comment["report_count"], 0)
        self.assertEqual(comment["moderation_status"], "visible")
        self.assertEqual(comment["author"]["username"], "Writer")


if __name__ == "__main__":
    unittest.main()
