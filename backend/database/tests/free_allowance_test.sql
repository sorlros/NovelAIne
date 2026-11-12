-- Checks free_allowance_20261112.sql. Run by run_sql_tests.sh after user_plans_test.sql,
-- whose user it reuses.
\set ON_ERROR_STOP on

CREATE FUNCTION pg_temp.check(ok boolean, what text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF ok IS NOT TRUE THEN RAISE EXCEPTION 'FAILED: %', what; END IF;
    RAISE NOTICE 'ok: %', what;
END $$;

-- Start the week over: a use last week, and one on Monday (today, when today is Monday).
DELETE FROM public.daily_usage WHERE kind = 'story';
INSERT INTO public.daily_usage (user_id, day, kind, count) VALUES
    ('00000000-0000-0000-0000-000000000001', date_trunc('week', (now() AT TIME ZONE 'Asia/Seoul')::date)::date - 1, 'story', 5),
    ('00000000-0000-0000-0000-000000000001', date_trunc('week', (now() AT TIME ZONE 'Asia/Seoul')::date)::date, 'story', 1);

SELECT pg_temp.check(public.use_weekly('00000000-0000-0000-0000-000000000001', 'story', 2),
                     'last week does not count, Monday does: the second story of the week is counted');
SELECT pg_temp.check(NOT public.use_weekly('00000000-0000-0000-0000-000000000001', 'story', 2),
                     'the third story of the week is refused');
SELECT pg_temp.check((SELECT sum(count) = 2 FROM public.daily_usage WHERE kind = 'story'
                       AND day >= date_trunc('week', (now() AT TIME ZONE 'Asia/Seoul')::date)::date),
                     'a refused use is not counted');

SELECT public.give_back_daily('00000000-0000-0000-0000-000000000001', 'story');
SELECT pg_temp.check(public.use_weekly('00000000-0000-0000-0000-000000000001', 'story', 2),
                     'a given back use can be used again');
SELECT pg_temp.check(NOT public.use_weekly('00000000-0000-0000-0000-000000000001', 'story', 0), 'a zero limit refuses');

SELECT pg_temp.check(NOT has_function_privilege(role, 'public.use_weekly(uuid, text, integer)', 'execute'),
                     role || ' cannot run use_weekly')
  FROM unnest(ARRAY['anon', 'authenticated']) AS role;
SELECT pg_temp.check(has_function_privilege('service_role', 'public.use_weekly(uuid, text, integer)', 'execute'),
                     'the backend can run use_weekly');
