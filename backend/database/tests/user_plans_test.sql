-- Checks user_plans_20261111.sql. Run by run_sql_tests.sh after story_play_limits_test.sql,
-- whose user it reuses.
\set ON_ERROR_STOP on

CREATE FUNCTION pg_temp.check(ok boolean, what text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF ok IS NOT TRUE THEN RAISE EXCEPTION 'FAILED: %', what; END IF;
    RAISE NOTICE 'ok: %', what;
END $$;

SELECT pg_temp.check(public.use_daily('00000000-0000-0000-0000-000000000001', 'turn', 2), 'first turn counted');
SELECT pg_temp.check(public.use_daily('00000000-0000-0000-0000-000000000001', 'turn', 2), 'second turn counted');
SELECT pg_temp.check(NOT public.use_daily('00000000-0000-0000-0000-000000000001', 'turn', 2), 'third turn refused');
SELECT pg_temp.check(public.use_daily('00000000-0000-0000-0000-000000000001', 'story', 1), 'another kind has its own count');
SELECT pg_temp.check((SELECT count = 2 FROM public.daily_usage WHERE kind = 'turn'), 'a refused use is not counted');

SELECT public.give_back_daily('00000000-0000-0000-0000-000000000001', 'turn');
SELECT pg_temp.check(public.use_daily('00000000-0000-0000-0000-000000000001', 'turn', 2), 'a given back use can be used again');
SELECT public.give_back_daily('00000000-0000-0000-0000-000000000001', 'direct_input');
SELECT pg_temp.check(NOT EXISTS (SELECT 1 FROM public.daily_usage WHERE count < 0), 'giving back never goes below zero');
SELECT pg_temp.check(NOT public.use_daily('00000000-0000-0000-0000-000000000001', 'turn', 0), 'a zero limit refuses');

SELECT pg_temp.check(NOT has_function_privilege(role, fn, 'execute'), role || ' cannot run ' || fn)
  FROM unnest(ARRAY['anon', 'authenticated']) AS role,
       unnest(ARRAY['public.use_daily(uuid, text, integer)', 'public.give_back_daily(uuid, text)']) AS fn;
SELECT pg_temp.check(NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename IN ('user_entitlements', 'daily_usage')),
                     'no client policies on the plan tables');
