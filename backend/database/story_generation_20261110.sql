-- NovelAIne skeleton-mode stories, step 2: background generation.
-- Apply after story_skeleton_20261110.sql and before deploying the matching API version.

-- The run currently holding a generation job. Taking a job over is a
-- compare-and-set on this column, so two runs never work on the same story.
ALTER TABLE public.story_plans
ADD COLUMN IF NOT EXISTS lease_owner text;

-- Used to count a user's stories still being generated (concurrency limit).
CREATE INDEX IF NOT EXISTS idx_stories_user_status
ON public.stories(user_id, status);
