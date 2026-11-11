-- NovelAIne skeleton-mode stories, step 4: limits on turns.
-- Apply after story_play_atomic_20261111.sql, before deploying the matching API version.
-- Every statement is idempotent. Only the backend calls the functions (service_role).

-- One turn at a time per story. A turn holds this from before its first model call until
-- its scene is saved or fails, so requests sent together do not each pay for a scene
-- that cannot be saved. It expires on its own if the server dies mid-turn.
ALTER TABLE public.stories ADD COLUMN IF NOT EXISTS turn_lock_owner text;
ALTER TABLE public.stories ADD COLUMN IF NOT EXISTS turn_lock_until timestamptz;

-- How many actions each user wrote themselves per day (Korean time). Kept apart from the
-- turns so undoing a turn does not give the use back.
CREATE TABLE IF NOT EXISTS public.play_input_usage (
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    day date NOT NULL,
    count integer NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, day)
);
ALTER TABLE public.play_input_usage ENABLE ROW LEVEL SECURITY;

-- Take the story's turn slot. Returns false while another turn holds it.
CREATE OR REPLACE FUNCTION public.claim_story_turn(p_story_id uuid, p_owner text, p_seconds integer)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    UPDATE public.stories
       SET turn_lock_owner = p_owner, turn_lock_until = now() + make_interval(secs => p_seconds)
     WHERE id = p_story_id AND (turn_lock_until IS NULL OR turn_lock_until < now());
    RETURN FOUND;
END;
$$;

-- Give the slot back. Only its owner can: a turn that outlived its lease leaves a newer one alone.
CREATE OR REPLACE FUNCTION public.release_story_turn(p_story_id uuid, p_owner text)
RETURNS void
LANGUAGE sql
SET search_path = public
AS $$
    UPDATE public.stories SET turn_lock_owner = NULL, turn_lock_until = NULL
     WHERE id = p_story_id AND turn_lock_owner = p_owner;
$$;

-- Count one written action for today. Returns false, counting nothing, once p_limit is reached.
CREATE OR REPLACE FUNCTION public.use_direct_input(p_user_id uuid, p_limit integer)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_count integer;
BEGIN
    IF p_limit <= 0 THEN
        RETURN false;
    END IF;
    INSERT INTO public.play_input_usage (user_id, day, count)
    VALUES (p_user_id, (now() AT TIME ZONE 'Asia/Seoul')::date, 1)
    ON CONFLICT (user_id, day) DO UPDATE SET count = play_input_usage.count + 1
     WHERE play_input_usage.count < p_limit
    RETURNING count INTO v_count;
    RETURN v_count IS NOT NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_story_turn(uuid, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.release_story_turn(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.use_direct_input(uuid, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_story_turn(uuid, text, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.release_story_turn(uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.use_direct_input(uuid, integer) TO service_role;
