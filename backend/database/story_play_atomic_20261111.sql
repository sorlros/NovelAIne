-- NovelAIne skeleton-mode stories, step 3: writes that must happen together.
-- Apply after story_skeleton_20261110.sql and story_generation_20261110.sql, before
-- deploying the matching API version. Every statement is idempotent.
--
-- Each function runs in one transaction. It first locks the row that decides whether
-- the write may happen (the story, or the generation job), so two requests for the
-- same story take turns, and a failure part way leaves nothing behind.
--
-- Only the backend calls these, with the service_role key. Execution is revoked from
-- every client role: each one would otherwise be callable through the REST API.

-- A reader's turn: move the story to the next beat, write that beat, and save the
-- reader's move and the new scene. Returns null when the story is no longer at
-- p_expected_seq (another turn or an undo came first); nothing is written then.
--   p_beat_id    the planned beat being written, or null to insert it (a major event
--                reached for the first time, or the first card of a replanned segment)
--   p_beat       {"spine_event_id": text|null, "card": jsonb}
--   p_replanned  null, or the rest of a segment planned again: [{"seq", "card"}].
--                The planned scene beats after the current one are replaced by these.
CREATE OR REPLACE FUNCTION public.save_story_turn(
    p_story_id uuid,
    p_expected_seq integer,
    p_next_seq integer,
    p_world_state jsonb,
    p_finished boolean,
    p_beat_id uuid,
    p_beat jsonb,
    p_replanned jsonb,
    p_user_content text,
    p_ai_content text,
    p_events jsonb,
    p_client_request_id text
) RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_beat_id uuid;
    v_sequence integer;
    v_user public.scenes;
    v_ai public.scenes;
BEGIN
    UPDATE public.stories
       SET current_beat_seq = p_next_seq,
           world_state = p_world_state,
           status = CASE WHEN p_finished THEN 'completed' ELSE status END
     WHERE id = p_story_id AND current_beat_seq = p_expected_seq;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    IF p_replanned IS NOT NULL THEN
        DELETE FROM public.story_beats
         WHERE story_id = p_story_id AND seq > p_expected_seq AND spine_event_id IS NULL;
        INSERT INTO public.story_beats (story_id, seq, spine_event_id, card, status)
        SELECT p_story_id, r.seq, NULL, r.card, 'planned'
          FROM jsonb_to_recordset(p_replanned) AS r(seq integer, card jsonb);
    END IF;

    IF p_beat_id IS NOT NULL THEN
        UPDATE public.story_beats SET card = p_beat->'card', status = 'written'
         WHERE id = p_beat_id AND story_id = p_story_id AND seq = p_next_seq
        RETURNING id INTO v_beat_id;
        IF v_beat_id IS NULL THEN
            RAISE EXCEPTION 'beat % is not beat % of story %', p_beat_id, p_next_seq, p_story_id;
        END IF;
    ELSE
        INSERT INTO public.story_beats (story_id, seq, spine_event_id, card, status)
        VALUES (p_story_id, p_next_seq, p_beat->>'spine_event_id', p_beat->'card', 'written')
        RETURNING id INTO v_beat_id;
    END IF;

    SELECT coalesce(max(sequence), 0) + 1 INTO v_sequence FROM public.scenes WHERE story_id = p_story_id;
    INSERT INTO public.scenes (story_id, content, sequence, scene_type, role, client_request_id)
    VALUES (p_story_id, p_user_content, v_sequence, 'dialogue', 'user', p_client_request_id)
    RETURNING * INTO v_user;
    INSERT INTO public.scenes (story_id, content, sequence, scene_type, role, client_request_id, beat_id, events)
    VALUES (p_story_id, p_ai_content, v_sequence + 1, 'narrative', 'ai', p_client_request_id, v_beat_id, p_events)
    RETURNING * INTO v_ai;

    UPDATE public.story_beats SET scene_id = v_ai.id WHERE id = v_beat_id;
    UPDATE public.stories SET current_scene_id = v_ai.id, total_scenes = v_sequence + 1 WHERE id = p_story_id;
    RETURN jsonb_build_object('user_scene', to_jsonb(v_user), 'ai_scene', to_jsonb(v_ai), 'beat_id', v_beat_id);
END;
$$;

-- Undo the turn that produced beat p_expected_seq: restore the state before it, remove
-- its two scenes, and put the beat back (a planned scene) or remove it and everything
-- planned after it (a major event). Returns false when the story is no longer at that
-- beat, or the beat cannot be undone (the opening).
CREATE OR REPLACE FUNCTION public.undo_story_turn(p_story_id uuid, p_expected_seq integer)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_beat public.story_beats;
    v_previous_seq integer;
    v_ai_sequence integer;
BEGIN
    PERFORM 1 FROM public.stories WHERE id = p_story_id AND current_beat_seq = p_expected_seq FOR UPDATE;
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    SELECT * INTO v_beat FROM public.story_beats WHERE story_id = p_story_id AND seq = p_expected_seq;
    IF v_beat.id IS NULL OR NOT (v_beat.card ? 'state_before') THEN
        RETURN false;
    END IF;
    v_previous_seq := (v_beat.card->>'previous_seq')::integer;

    SELECT sequence INTO v_ai_sequence FROM public.scenes WHERE id = v_beat.scene_id;
    IF v_ai_sequence IS NOT NULL THEN
        DELETE FROM public.scenes
         WHERE story_id = p_story_id
           AND (id = v_beat.scene_id OR (sequence = v_ai_sequence - 1 AND role = 'user'));
    END IF;

    IF v_beat.spine_event_id IS NOT NULL THEN
        DELETE FROM public.story_beats WHERE story_id = p_story_id AND seq >= v_beat.seq;
    ELSE
        UPDATE public.story_beats
           SET card = v_beat.card - 'callbacks' - 'state_before' - 'previous_seq' - 'chosen',
               status = 'planned', scene_id = NULL
         WHERE id = v_beat.id;
    END IF;

    UPDATE public.stories
       SET current_beat_seq = v_previous_seq,
           world_state = v_beat.card->'state_before',
           status = 'active',
           current_scene_id = (SELECT scene_id FROM public.story_beats
                                WHERE story_id = p_story_id AND seq = v_previous_seq),
           total_scenes = (SELECT coalesce(max(sequence), 0) FROM public.scenes WHERE story_id = p_story_id)
     WHERE id = p_story_id;
    RETURN true;
END;
$$;

-- After a major event's scene: save the choices shown under it (p_card) and the planned
-- scenes of the next segment (p_rows: [{"seq", "card"}]). Only while the reader is still
-- at that major event; returns false otherwise (it was undone meanwhile).
CREATE OR REPLACE FUNCTION public.save_next_segment(p_story_id uuid, p_beat_id uuid, p_card jsonb, p_rows jsonb)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_seq integer;
BEGIN
    SELECT b.seq INTO v_seq
      FROM public.story_beats b
      JOIN public.stories s ON s.id = b.story_id
     WHERE b.id = p_beat_id AND s.id = p_story_id AND s.current_beat_seq = b.seq
       FOR UPDATE OF s;
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    -- Left over from an attempt that stopped part way.
    DELETE FROM public.story_beats WHERE story_id = p_story_id AND seq > v_seq;
    INSERT INTO public.story_beats (story_id, seq, spine_event_id, card, status)
    SELECT p_story_id, r.seq, NULL, r.card, 'planned'
      FROM jsonb_to_recordset(p_rows) AS r(seq integer, card jsonb);
    UPDATE public.story_beats SET card = p_card WHERE id = p_beat_id;
    RETURN true;
END;
$$;

-- Story generation: replace the story's beats with the first major event and the first
-- segment (p_rows: [{"seq", "spine_event_id", "card"}]) and record the step, only while
-- p_owner holds the generation lease. Returns false when the lease was lost.
CREATE OR REPLACE FUNCTION public.replace_first_beats(
    p_story_id uuid, p_owner text, p_rows jsonb, p_lease_until timestamptz
) RETURNS boolean
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    PERFORM 1 FROM public.story_plans WHERE story_id = p_story_id AND lease_owner = p_owner FOR UPDATE;
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    DELETE FROM public.story_beats WHERE story_id = p_story_id;
    INSERT INTO public.story_beats (story_id, seq, spine_event_id, card, status)
    SELECT p_story_id, r.seq, r.spine_event_id, r.card, 'planned'
      FROM jsonb_to_recordset(p_rows) AS r(seq integer, spine_event_id text, card jsonb);
    UPDATE public.story_plans SET step = 'segment', lease_until = p_lease_until WHERE story_id = p_story_id;
    RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.save_story_turn(uuid, integer, integer, jsonb, boolean, uuid, jsonb, jsonb, text, text, jsonb, text)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.undo_story_turn(uuid, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.save_next_segment(uuid, uuid, jsonb, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.replace_first_beats(uuid, text, jsonb, timestamptz) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.save_story_turn(uuid, integer, integer, jsonb, boolean, uuid, jsonb, jsonb, text, text, jsonb, text)
    TO service_role;
GRANT EXECUTE ON FUNCTION public.undo_story_turn(uuid, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.save_next_segment(uuid, uuid, jsonb, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.replace_first_beats(uuid, text, jsonb, timestamptz) TO service_role;
