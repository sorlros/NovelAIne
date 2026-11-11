#!/usr/bin/env bash
# Applies schema.sql and every migration to a throwaway Postgres (Docker) and runs the SQL checks.
# Usage: backend/database/tests/run_sql_tests.sh   (needs Docker; removes its container when done)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
database="$(dirname "$here")"
container="novelaine-sql-test-$$"

docker run -d --rm --name "$container" -e POSTGRES_PASSWORD=test pgvector/pgvector:pg16 >/dev/null
trap 'docker stop "$container" >/dev/null' EXIT
until docker exec "$container" pg_isready -U postgres -q; do sleep 1; done
sleep 1

psql() { docker exec -i "$container" psql -U postgres -q -v ON_ERROR_STOP=1 "$@"; }

# What Supabase provides: the auth schema and the API roles.
psql <<'SQL'
CREATE SCHEMA auth;
CREATE TABLE auth.users (id uuid PRIMARY KEY);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS 'SELECT NULL::uuid';
CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
SQL

for file in schema.sql service_hardening_20260601.sql update_genre_constraint.sql \
            update_llm_model_defaults_20260604.sql story_skeleton_20261110.sql \
            story_generation_20261110.sql story_play_atomic_20261111.sql \
            story_play_limits_20261111.sql story_play_metrics_20261111.sql \
            user_plans_20261111.sql; do
    psql < "$database/$file"
done

psql -o /dev/null < "$here/story_play_atomic_test.sql"
psql -o /dev/null < "$here/story_play_limits_test.sql"
psql -o /dev/null < "$here/user_plans_test.sql"

# Two turns sent at once: the second waits for the first, then finds the story moved on.
psql -c "UPDATE public.stories SET current_beat_seq = 1" >/dev/null
turn="SELECT public.save_story_turn('00000000-0000-0000-0000-0000000000aa', 1, 2, '{}', false,
      (SELECT id FROM public.story_beats WHERE seq = 2), '{\"card\": {}}', NULL, 'a', 'b', '[]', NULL) IS NULL"
psql -c "BEGIN; $turn; SELECT pg_sleep(2); COMMIT;" >/dev/null &
sleep 0.5
second="$(psql -At -c "$turn")"
wait
[ "$second" = "t" ] || { echo "FAILED: a concurrent turn on the same beat was saved too"; exit 1; }
echo "ok: a concurrent turn waits and is refused"
echo "all SQL checks passed"
