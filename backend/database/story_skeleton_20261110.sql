-- NovelAIne skeleton-mode stories, step 1: tables and columns.
-- Apply in Supabase SQL Editor before deploying the matching API version.
-- Every statement is idempotent. Existing stories keep mode = 'legacy' and are not affected.

-- ============================================
-- Server-only tables
-- ============================================
-- These hold the ending and the events still ahead of the reader, so clients
-- must never read them. RLS is enabled with no policy at all: only a key that
-- bypasses RLS (the service_role key on the backend) can read or write them.

CREATE TABLE IF NOT EXISTS public.story_plans (
    story_id uuid PRIMARY KEY REFERENCES public.stories(id) ON DELETE CASCADE,
    world jsonb,
    spine jsonb,
    status text NOT NULL DEFAULT 'queued',
    step text NOT NULL DEFAULT 'none',
    lease_until timestamptz,
    request_id text,
    seed jsonb NOT NULL DEFAULT '{}'::jsonb,
    attempts integer NOT NULL DEFAULT 0,
    error text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.story_plans DROP CONSTRAINT IF EXISTS story_plans_status_check;
ALTER TABLE public.story_plans
ADD CONSTRAINT story_plans_status_check
CHECK (status IN ('queued', 'running', 'ready', 'failed'));

ALTER TABLE public.story_plans DROP CONSTRAINT IF EXISTS story_plans_step_check;
ALTER TABLE public.story_plans
ADD CONSTRAINT story_plans_step_check
CHECK (step IN ('none', 'world', 'spine', 'segment', 'opening'));

-- A retried create request with the same id must not make a second story.
CREATE UNIQUE INDEX IF NOT EXISTS idx_story_plans_request_id
ON public.story_plans(request_id)
WHERE request_id IS NOT NULL;

-- Used to find generation jobs whose runner died (lease expired).
CREATE INDEX IF NOT EXISTS idx_story_plans_pending
ON public.story_plans(status, lease_until)
WHERE status IN ('queued', 'running');

CREATE TABLE IF NOT EXISTS public.story_beats (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    story_id uuid NOT NULL REFERENCES public.stories(id) ON DELETE CASCADE,
    seq integer NOT NULL,
    spine_event_id text,
    card jsonb NOT NULL,
    status text NOT NULL DEFAULT 'planned',
    scene_id uuid REFERENCES public.scenes(id) ON DELETE SET NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE (story_id, seq)
);

ALTER TABLE public.story_beats DROP CONSTRAINT IF EXISTS story_beats_status_check;
ALTER TABLE public.story_beats
ADD CONSTRAINT story_beats_status_check
CHECK (status IN ('planned', 'written', 'dropped'));

ALTER TABLE public.story_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_beats ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS update_story_plans_updated_at ON public.story_plans;
CREATE TRIGGER update_story_plans_updated_at BEFORE UPDATE ON public.story_plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_story_beats_updated_at ON public.story_beats;
CREATE TRIGGER update_story_beats_updated_at BEFORE UPDATE ON public.story_beats
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Columns on existing tables
-- ============================================

ALTER TABLE public.stories
ADD COLUMN IF NOT EXISTS mode text DEFAULT 'legacy';

ALTER TABLE public.stories DROP CONSTRAINT IF EXISTS stories_mode_check;
ALTER TABLE public.stories
ADD CONSTRAINT stories_mode_check
CHECK (mode IN ('legacy', 'skeleton'));

-- World state of a skeleton story: who is alive and where, who holds what,
-- relations, and established facts. Public stories expose it, but it only
-- contains what the published prose already shows.
ALTER TABLE public.stories
ADD COLUMN IF NOT EXISTS world_state jsonb;

ALTER TABLE public.stories
ADD COLUMN IF NOT EXISTS current_beat_seq integer;

-- 'generating' while the skeleton is being built, 'failed' when it gave up.
ALTER TABLE public.stories DROP CONSTRAINT IF EXISTS stories_status_check;
ALTER TABLE public.stories
ADD CONSTRAINT stories_status_check
CHECK (status IN ('active', 'completed', 'archived', 'generating', 'failed'));

ALTER TABLE public.scenes
ADD COLUMN IF NOT EXISTS beat_id uuid REFERENCES public.story_beats(id) ON DELETE SET NULL;

-- Events applied in the turn that produced this scene, including the reader's choice.
-- Undo and state rebuilds replay these.
ALTER TABLE public.scenes
ADD COLUMN IF NOT EXISTS events jsonb;
