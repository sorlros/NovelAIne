-- NovelAIne: the free plan's stories are counted per week (2 a Korean week, from Monday).
-- Apply after user_plans_20261111.sql, before deploying the matching API version.
-- Every statement is idempotent. Only the backend calls the function (service_role).

-- Count one use of p_kind for today, against p_limit for this Korean week. Returns false, counting
-- nothing, once the week's uses reach p_limit. Today's daily_usage row holds the use, so
-- give_back_daily gives it back as it does for the daily limits.
CREATE OR REPLACE FUNCTION public.use_weekly(p_user_id uuid, p_kind text, p_limit integer)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_today date := (now() AT TIME ZONE 'Asia/Seoul')::date;
    v_used integer;
BEGIN
    IF p_limit <= 0 THEN
        RETURN false;
    END IF;
    -- The week's total is read before today's row is written: one use of a user's kind at a time.
    PERFORM pg_advisory_xact_lock(hashtext('use_weekly:' || p_user_id::text || ':' || p_kind));
    SELECT coalesce(sum(count), 0) INTO v_used
      FROM public.daily_usage
     WHERE user_id = p_user_id AND kind = p_kind
       AND day BETWEEN date_trunc('week', v_today)::date AND v_today;
    IF v_used >= p_limit THEN
        RETURN false;
    END IF;
    INSERT INTO public.daily_usage (user_id, day, kind, count)
    VALUES (p_user_id, v_today, p_kind, 1)
    ON CONFLICT (user_id, day, kind) DO UPDATE SET count = daily_usage.count + 1;
    RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.use_weekly(uuid, text, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.use_weekly(uuid, text, integer) TO service_role;
