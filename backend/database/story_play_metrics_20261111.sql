-- NovelAIne skeleton-mode stories, step 5: one row per turn, for measuring the switch.
-- Apply after story_play_limits_20261111.sql, before deploying the matching API version.
-- Every statement is idempotent. Written by the backend only; queries are in queries/play_metrics.sql.

CREATE TABLE IF NOT EXISTS public.play_turn_log (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    story_id uuid NOT NULL REFERENCES public.stories(id) ON DELETE CASCADE,
    user_id uuid,
    beat_seq integer,             -- the beat the turn wrote
    major_event boolean NOT NULL DEFAULT false,
    kind text NOT NULL,           -- 'choice' or 'free' (the reader wrote it)
    input_judgement text,         -- for 'free': 'holds', 'fails' (written as a failed attempt) or 'outside'
    replanned boolean NOT NULL DEFAULT false,
    choices_offered integer,      -- how many choices the reader had when taking this turn
    prepare_ms integer,           -- reading the input, replanning: everything before the scene
    first_chunk_ms integer,
    stream_ms integer,
    brief text,                   -- what the scene writer was given, to compare with the scene by hand
    prose_chars integer,
    model text,
    outcome text NOT NULL,        -- 'saved', 'conflict' (another turn came first) or 'failed'
    error text,
    scene_id uuid,                -- the saved scene, when outcome is 'saved'
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_play_turn_log_created ON public.play_turn_log(created_at);

-- Holds the briefs, which describe what is still ahead of the reader: no client may read it.
ALTER TABLE public.play_turn_log ENABLE ROW LEVEL SECURITY;
