-- Checks story_play_atomic_20261111.sql against a real Postgres. Run by run_sql_tests.sh.
-- Every check raises an exception when it fails, so psql stops with an error.
\set ON_ERROR_STOP on

-- A skeleton story at its opening (beat 1, a major event), with two planned scenes after it.
INSERT INTO auth.users (id) VALUES ('00000000-0000-0000-0000-000000000001');
INSERT INTO public.users (id, email, username) VALUES ('00000000-0000-0000-0000-000000000001', 'a@b.c', 'reader');
INSERT INTO public.stories (id, user_id, title, genre, mode, status, current_beat_seq, world_state)
VALUES ('00000000-0000-0000-0000-0000000000aa', '00000000-0000-0000-0000-000000000001', '시험', 'fantasy',
        'skeleton', 'active', 1, '{"turn": 0}');
INSERT INTO public.story_plans (story_id, status, step, lease_owner) VALUES ('00000000-0000-0000-0000-0000000000aa', 'ready', 'opening', 'run-1');
INSERT INTO public.story_beats (id, story_id, seq, spine_event_id, card, status) VALUES
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000aa', 1, 'e01', '{"id": "e01"}', 'written'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000aa', 2, NULL, '{"id": "s1"}', 'planned'),
  ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-0000000000aa', 3, NULL, '{"id": "s2"}', 'planned');
INSERT INTO public.scenes (id, story_id, content, sequence, role, beat_id)
VALUES ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000aa', '첫 장면', 1, 'ai',
        '00000000-0000-0000-0000-0000000000b1');
UPDATE public.story_beats SET scene_id = '00000000-0000-0000-0000-0000000000c1' WHERE seq = 1;

CREATE FUNCTION pg_temp.check(ok boolean, what text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF ok IS NOT TRUE THEN RAISE EXCEPTION 'FAILED: %', what; END IF;
    RAISE NOTICE 'ok: %', what;
END $$;

CREATE FUNCTION pg_temp.turn(expected integer, beat uuid, card jsonb, replanned jsonb DEFAULT NULL) RETURNS jsonb
LANGUAGE sql AS $$
    SELECT public.save_story_turn('00000000-0000-0000-0000-0000000000aa', expected, expected + 1,
        jsonb_build_object('turn', expected), false, beat, jsonb_build_object('spine_event_id', NULL, 'card', card),
        replanned, '고른 선택', '새 장면', '[{"type": "act"}]', 'req-' || expected)
$$;

-- A turn writes the planned beat, both scenes and the pointers together.
SELECT pg_temp.check(pg_temp.turn(1, '00000000-0000-0000-0000-0000000000b2', '{"id": "s1", "state_before": {"turn": 0}, "previous_seq": 1}') IS NOT NULL, 'turn saved');
SELECT pg_temp.check((SELECT current_beat_seq = 2 AND world_state = '{"turn": 1}' AND total_scenes = 3
                        AND current_scene_id = (SELECT id FROM public.scenes WHERE sequence = 3)
                      FROM public.stories), 'story moved to beat 2');
SELECT pg_temp.check((SELECT status = 'written' AND scene_id IS NOT NULL FROM public.story_beats WHERE seq = 2), 'beat 2 written');
SELECT pg_temp.check((SELECT array_agg(role ORDER BY sequence) = '{ai,user,ai}' FROM public.scenes), 'reader move and scene saved');

-- The same turn again (another device, a retry): nothing happens.
SELECT pg_temp.check(pg_temp.turn(1, '00000000-0000-0000-0000-0000000000b2', '{"id": "s1"}') IS NULL, 'stale turn refused');
SELECT pg_temp.check((SELECT count(*) = 3 FROM public.scenes), 'stale turn wrote nothing');

-- A turn that fails part way leaves nothing behind, the story pointer included.
DO $$
BEGIN
    PERFORM pg_temp.turn(2, '00000000-0000-0000-0000-0000000000ff', '{"id": "x"}');
    RAISE EXCEPTION 'FAILED: a missing beat should have stopped the turn';
EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'FAILED:%' THEN RAISE; END IF;
END $$;
SELECT pg_temp.check((SELECT current_beat_seq = 2 AND world_state = '{"turn": 1}' FROM public.stories), 'failed turn rolled back');
SELECT pg_temp.check((SELECT count(*) = 3 FROM public.scenes), 'failed turn left no scenes');

-- Undo puts everything back.
SELECT pg_temp.check(public.undo_story_turn('00000000-0000-0000-0000-0000000000aa', 2), 'undo done');
SELECT pg_temp.check((SELECT current_beat_seq = 1 AND world_state = '{"turn": 0}' AND total_scenes = 1
                        AND current_scene_id = '00000000-0000-0000-0000-0000000000c1' FROM public.stories), 'story back at beat 1');
SELECT pg_temp.check((SELECT count(*) = 1 FROM public.scenes), 'turn scenes removed');
SELECT pg_temp.check((SELECT status = 'planned' AND scene_id IS NULL AND NOT card ? 'state_before'
                      FROM public.story_beats WHERE seq = 2), 'beat 2 planned again');
SELECT pg_temp.check(NOT public.undo_story_turn('00000000-0000-0000-0000-0000000000aa', 2), 'stale undo refused');
SELECT pg_temp.check(NOT public.undo_story_turn('00000000-0000-0000-0000-0000000000aa', 1), 'the opening cannot be undone');

-- A replanned segment replaces the planned beats only when the turn is saved.
SELECT pg_temp.check(pg_temp.turn(1, NULL, '{"id": "r1", "state_before": {"turn": 0}, "previous_seq": 1}',
                                  '[{"seq": 3, "card": {"id": "r2"}}]') IS NOT NULL, 'replanned turn saved');
SELECT pg_temp.check((SELECT array_agg(card->>'id' ORDER BY seq) = '{e01,r1,r2}' FROM public.story_beats), 'segment replaced');
SELECT pg_temp.check(public.undo_story_turn('00000000-0000-0000-0000-0000000000aa', 2), 'replanned turn undone');

-- The next segment is saved only while the reader is at its major event.
UPDATE public.stories SET current_beat_seq = 2;
SELECT pg_temp.check(NOT public.save_next_segment('00000000-0000-0000-0000-0000000000aa', '00000000-0000-0000-0000-0000000000b1',
                                                  '{"id": "e01", "choices": [1]}', '[{"seq": 2, "card": {"id": "n1"}}]'), 'segment refused after moving on');
UPDATE public.stories SET current_beat_seq = 1;
SELECT pg_temp.check(public.save_next_segment('00000000-0000-0000-0000-0000000000aa', '00000000-0000-0000-0000-0000000000b1',
                                              '{"id": "e01", "choices": [1]}', '[{"seq": 2, "card": {"id": "n1"}}]'), 'segment saved');
SELECT pg_temp.check((SELECT array_agg(card->>'id' ORDER BY seq) = '{e01,n1}' FROM public.story_beats), 'leftover beats replaced');
SELECT pg_temp.check((SELECT card ? 'choices' FROM public.story_beats WHERE seq = 1), 'choices saved with the segment');

-- First beats are replaced only by the run holding the generation lease.
SELECT pg_temp.check(NOT public.replace_first_beats('00000000-0000-0000-0000-0000000000aa', 'run-0',
                     '[{"seq": 1, "spine_event_id": "e01", "card": {}}]', now()), 'lost lease refused');
SELECT pg_temp.check((SELECT count(*) = 2 FROM public.story_beats), 'beats kept for the lease holder');
DELETE FROM public.scenes;
SELECT pg_temp.check(public.replace_first_beats('00000000-0000-0000-0000-0000000000aa', 'run-1',
                     '[{"seq": 1, "spine_event_id": "e01", "card": {"id": "e01"}}, {"seq": 2, "spine_event_id": null, "card": {"id": "s1"}}]',
                     now()), 'lease holder replaced beats');
SELECT pg_temp.check((SELECT step = 'segment' FROM public.story_plans), 'step recorded with the beats');

-- Clients cannot call any of them through the REST API.
SELECT pg_temp.check(NOT has_function_privilege(role, fn, 'execute'), role || ' cannot run ' || fn)
  FROM unnest(ARRAY['anon', 'authenticated']) AS role,
       unnest(ARRAY['public.save_story_turn(uuid, integer, integer, jsonb, boolean, uuid, jsonb, jsonb, text, text, jsonb, text)',
                    'public.undo_story_turn(uuid, integer)', 'public.save_next_segment(uuid, uuid, jsonb, jsonb)',
                    'public.replace_first_beats(uuid, text, jsonb, timestamptz)']) AS fn;
SELECT pg_temp.check(has_function_privilege('service_role', 'public.undo_story_turn(uuid, integer)', 'execute'), 'service_role can run them');
