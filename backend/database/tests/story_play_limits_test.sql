-- Checks story_play_limits_20261111.sql. Run by run_sql_tests.sh after story_play_atomic_test.sql,
-- whose story and user it reuses.
\set ON_ERROR_STOP on

CREATE FUNCTION pg_temp.check(ok boolean, what text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF ok IS NOT TRUE THEN RAISE EXCEPTION 'FAILED: %', what; END IF;
    RAISE NOTICE 'ok: %', what;
END $$;

-- One turn at a time.
SELECT pg_temp.check(public.claim_story_turn('00000000-0000-0000-0000-0000000000aa', 'turn-a', 300), 'first turn takes the slot');
SELECT pg_temp.check(NOT public.claim_story_turn('00000000-0000-0000-0000-0000000000aa', 'turn-b', 300), 'second turn is refused');
SELECT public.release_story_turn('00000000-0000-0000-0000-0000000000aa', 'turn-b');
SELECT pg_temp.check((SELECT turn_lock_owner = 'turn-a' FROM public.stories), 'only the owner releases it');
SELECT public.release_story_turn('00000000-0000-0000-0000-0000000000aa', 'turn-a');
SELECT pg_temp.check(public.claim_story_turn('00000000-0000-0000-0000-0000000000aa', 'turn-b', 300), 'free again after release');
UPDATE public.stories SET turn_lock_until = now() - interval '1 second';
SELECT pg_temp.check(public.claim_story_turn('00000000-0000-0000-0000-0000000000aa', 'turn-c', 300), 'an expired slot can be taken');
SELECT public.release_story_turn('00000000-0000-0000-0000-0000000000aa', 'turn-c');

-- Daily written actions.
SELECT pg_temp.check(public.use_direct_input('00000000-0000-0000-0000-000000000001', 2), 'first use counted');
SELECT pg_temp.check(public.use_direct_input('00000000-0000-0000-0000-000000000001', 2), 'second use counted');
SELECT pg_temp.check(NOT public.use_direct_input('00000000-0000-0000-0000-000000000001', 2), 'third use refused at the limit');
SELECT pg_temp.check((SELECT count = 2 FROM public.play_input_usage), 'a refused use is not counted');
SELECT pg_temp.check(NOT public.use_direct_input('00000000-0000-0000-0000-000000000001', 0), 'a zero limit refuses');
SELECT pg_temp.check((SELECT day = (now() AT TIME ZONE 'Asia/Seoul')::date FROM public.play_input_usage), 'counted on the Korean day');

SELECT pg_temp.check(NOT has_function_privilege(role, fn, 'execute'), role || ' cannot run ' || fn)
  FROM unnest(ARRAY['anon', 'authenticated']) AS role,
       unnest(ARRAY['public.claim_story_turn(uuid, text, integer)', 'public.release_story_turn(uuid, text)',
                    'public.use_direct_input(uuid, integer)']) AS fn;
