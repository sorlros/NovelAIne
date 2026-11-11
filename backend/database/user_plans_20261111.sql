-- NovelAIne paid plans and the daily limits of each plan.
-- Apply after story_play_limits_20261111.sql, before deploying the matching API version.
-- Every statement is idempotent. Only the backend reads these tables and calls the functions (service_role).

-- Who has a paid plan. A row only for users who paid (or were given a plan); everyone else is free.
-- Server only: no RLS policies, so a user can never grant themselves a plan through the client.
CREATE TABLE IF NOT EXISTS public.user_entitlements (
    user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    plan text NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'premium')),
    expires_at timestamptz,  -- null: until changed
    source text,             -- 'manual' for now; later the payment provider
    updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.user_entitlements ENABLE ROW LEVEL SECURITY;

-- What each user used per day (Korean time): new stories, turns, written actions.
CREATE TABLE IF NOT EXISTS public.daily_usage (
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    day date NOT NULL,
    kind text NOT NULL CHECK (kind IN ('story', 'turn', 'direct_input')),
    count integer NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, day, kind)
);
ALTER TABLE public.daily_usage ENABLE ROW LEVEL SECURITY;

-- Count one use of p_kind for today. Returns false, counting nothing, once p_limit is reached.
CREATE OR REPLACE FUNCTION public.use_daily(p_user_id uuid, p_kind text, p_limit integer)
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
    INSERT INTO public.daily_usage (user_id, day, kind, count)
    VALUES (p_user_id, (now() AT TIME ZONE 'Asia/Seoul')::date, p_kind, 1)
    ON CONFLICT (user_id, day, kind) DO UPDATE SET count = daily_usage.count + 1
     WHERE daily_usage.count < p_limit
    RETURNING count INTO v_count;
    RETURN v_count IS NOT NULL;
END;
$$;

-- Give back one use of today, for a request that failed before it gave the user anything.
CREATE OR REPLACE FUNCTION public.give_back_daily(p_user_id uuid, p_kind text)
RETURNS void
LANGUAGE sql
SET search_path = public
AS $$
    UPDATE public.daily_usage SET count = count - 1
     WHERE user_id = p_user_id AND kind = p_kind AND count > 0
       AND day = (now() AT TIME ZONE 'Asia/Seoul')::date;
$$;

REVOKE ALL ON FUNCTION public.use_daily(uuid, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.give_back_daily(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.use_daily(uuid, text, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.give_back_daily(uuid, text) TO service_role;

-- Written actions were counted in play_input_usage until now: keep today's count.
INSERT INTO public.daily_usage (user_id, day, kind, count)
SELECT user_id, day, 'direct_input', count FROM public.play_input_usage
 WHERE day = (now() AT TIME ZONE 'Asia/Seoul')::date
ON CONFLICT (user_id, day, kind) DO NOTHING;

-- Give a user the paid plan by hand (until payments exist):
--   INSERT INTO public.user_entitlements (user_id, plan, source) VALUES ('<user id>', 'premium', 'manual')
--   ON CONFLICT (user_id) DO UPDATE SET plan = 'premium', expires_at = NULL, source = 'manual', updated_at = now();
