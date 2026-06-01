-- NovelAIne service hardening migration
-- Apply in Supabase SQL Editor before deploying the matching API version.

-- Keep genre support aligned with backend Pydantic validation and Flutter UI.
ALTER TABLE public.stories
DROP CONSTRAINT IF EXISTS stories_genre_check;

ALTER TABLE public.stories
ADD CONSTRAINT stories_genre_check
CHECK (genre IN (
    'fantasy',
    'scifi',
    'mystery',
    'romance',
    'horror',
    'adventure',
    'wuxia',
    'apocalypse',
    'cyberpunk',
    'other'
));

-- Persist chat turns and generated media URLs directly on scenes.
ALTER TABLE public.scenes
ADD COLUMN IF NOT EXISTS role text DEFAULT 'ai';

ALTER TABLE public.scenes
DROP CONSTRAINT IF EXISTS scenes_role_check;

ALTER TABLE public.scenes
ADD CONSTRAINT scenes_role_check
CHECK (role IN ('user', 'ai', 'system'));

ALTER TABLE public.scenes
ADD COLUMN IF NOT EXISTS image_url text;

ALTER TABLE public.scenes
ADD COLUMN IF NOT EXISTS bgm_url text;

-- Prevent duplicate chat turns when mobile/web clients retry a request.
ALTER TABLE public.scenes
ADD COLUMN IF NOT EXISTS client_request_id text;

CREATE UNIQUE INDEX IF NOT EXISTS idx_scenes_client_request_role
ON public.scenes(story_id, client_request_id, role)
WHERE client_request_id IS NOT NULL;

-- Support character vault filtering in Flutter.
ALTER TABLE public.characters
ADD COLUMN IF NOT EXISTS is_in_vault boolean DEFAULT false;

-- Public library / explore support.
ALTER TABLE public.stories
ADD COLUMN IF NOT EXISTS visibility text DEFAULT 'private';

ALTER TABLE public.stories
DROP CONSTRAINT IF EXISTS stories_visibility_check;

ALTER TABLE public.stories
ADD CONSTRAINT stories_visibility_check
CHECK (visibility IN ('private', 'public'));

ALTER TABLE public.stories
ADD COLUMN IF NOT EXISTS published_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_stories_visibility
ON public.stories (visibility, published_at DESC);

DROP POLICY IF EXISTS stories_public_read ON public.stories;
CREATE POLICY stories_public_read ON public.stories
    FOR SELECT USING (visibility = 'public');

DROP POLICY IF EXISTS scenes_public_read ON public.scenes;
CREATE POLICY scenes_public_read ON public.scenes
    FOR SELECT USING (
        story_id IN (SELECT id FROM public.stories WHERE visibility = 'public')
    );

DROP POLICY IF EXISTS choices_public_read ON public.choices;
CREATE POLICY choices_public_read ON public.choices
    FOR SELECT USING (scene_id IN (
        SELECT s.id
        FROM public.scenes s
        JOIN public.stories t ON s.story_id = t.id
        WHERE t.visibility = 'public'
    ));

DROP POLICY IF EXISTS characters_public_story_read ON public.characters;
CREATE POLICY characters_public_story_read ON public.characters
    FOR SELECT USING (id IN (
        SELECT sc.character_id
        FROM public.story_characters sc
        JOIN public.stories t ON sc.story_id = t.id
        WHERE t.visibility = 'public'
    ));

DROP POLICY IF EXISTS story_characters_public_read ON public.story_characters;
CREATE POLICY story_characters_public_read ON public.story_characters
    FOR SELECT USING (
        story_id IN (SELECT id FROM public.stories WHERE visibility = 'public')
    );

-- Community feed support: likes and comments on public stories.
CREATE TABLE IF NOT EXISTS public.story_reactions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    story_id uuid REFERENCES public.stories(id) ON DELETE CASCADE NOT NULL,
    user_id uuid REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    reaction_type text DEFAULT 'like' CHECK (reaction_type IN ('like')),
    created_at timestamptz DEFAULT now(),
    UNIQUE(story_id, user_id, reaction_type)
);

CREATE TABLE IF NOT EXISTS public.story_comments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    story_id uuid REFERENCES public.stories(id) ON DELETE CASCADE NOT NULL,
    user_id uuid REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    content text NOT NULL CHECK (char_length(trim(content)) BETWEEN 1 AND 1000),
    is_deleted boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_story_reactions_story
ON public.story_reactions(story_id);

CREATE INDEX IF NOT EXISTS idx_story_reactions_user
ON public.story_reactions(user_id);

CREATE INDEX IF NOT EXISTS idx_story_comments_story
ON public.story_comments(story_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_story_comments_user
ON public.story_comments(user_id);

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_story_comments_updated_at
ON public.story_comments;
CREATE TRIGGER update_story_comments_updated_at
    BEFORE UPDATE ON public.story_comments
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.story_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_comments ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.story_comments
ADD COLUMN IF NOT EXISTS report_count integer DEFAULT 0;

ALTER TABLE public.story_comments
ADD COLUMN IF NOT EXISTS moderation_status text DEFAULT 'visible';

ALTER TABLE public.story_comments
DROP CONSTRAINT IF EXISTS story_comments_moderation_status_check;

ALTER TABLE public.story_comments
ADD CONSTRAINT story_comments_moderation_status_check
CHECK (moderation_status IN ('visible', 'hidden'));

CREATE INDEX IF NOT EXISTS idx_story_comments_moderation
ON public.story_comments(moderation_status, report_count);

DROP POLICY IF EXISTS story_reactions_read_public ON public.story_reactions;
CREATE POLICY story_reactions_read_public ON public.story_reactions
    FOR SELECT USING (
        story_id IN (
            SELECT id FROM public.stories
            WHERE visibility = 'public' OR user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS story_reactions_write_own ON public.story_reactions;
CREATE POLICY story_reactions_write_own ON public.story_reactions
    FOR ALL USING (auth.uid() = user_id)
    WITH CHECK (
        auth.uid() = user_id
        AND story_id IN (
            SELECT id FROM public.stories
            WHERE visibility = 'public' OR user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS story_comments_read_public ON public.story_comments;
CREATE POLICY story_comments_read_public ON public.story_comments
    FOR SELECT USING (
        is_deleted = false
        AND story_id IN (
            SELECT id FROM public.stories
            WHERE visibility = 'public' OR user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS story_comments_insert_own ON public.story_comments;
CREATE POLICY story_comments_insert_own ON public.story_comments
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
        AND story_id IN (
            SELECT id FROM public.stories
            WHERE visibility = 'public' OR user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS story_comments_delete_own_or_story_owner
ON public.story_comments;
CREATE POLICY story_comments_delete_own_or_story_owner
ON public.story_comments
    FOR DELETE USING (
        auth.uid() = user_id
        OR story_id IN (SELECT id FROM public.stories WHERE user_id = auth.uid())
    );

CREATE TABLE IF NOT EXISTS public.comment_reports (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    comment_id uuid REFERENCES public.story_comments(id) ON DELETE CASCADE NOT NULL,
    story_id uuid REFERENCES public.stories(id) ON DELETE CASCADE NOT NULL,
    reporter_id uuid REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    reason text NOT NULL,
    created_at timestamptz DEFAULT now(),
    UNIQUE(comment_id, reporter_id)
);

CREATE INDEX IF NOT EXISTS idx_comment_reports_comment
ON public.comment_reports(comment_id);

CREATE INDEX IF NOT EXISTS idx_comment_reports_reporter
ON public.comment_reports(reporter_id);

ALTER TABLE public.comment_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS comment_reports_own ON public.comment_reports;
CREATE POLICY comment_reports_own ON public.comment_reports
    FOR ALL USING (auth.uid() = reporter_id)
    WITH CHECK (
        auth.uid() = reporter_id
        AND story_id IN (
            SELECT id FROM public.stories
            WHERE visibility = 'public' OR user_id = auth.uid()
        )
    );

-- Durable media generation jobs for long-running image/BGM tasks.
CREATE TABLE IF NOT EXISTS public.media_jobs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    story_id uuid REFERENCES public.stories(id) ON DELETE CASCADE NOT NULL,
    scene_id uuid REFERENCES public.scenes(id) ON DELETE CASCADE NOT NULL,
    media_type text NOT NULL CHECK (media_type IN ('image', 'bgm')),
    scene_type text DEFAULT 'event' CHECK (scene_type IN ('dialogue', 'event')),
    status text DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'succeeded', 'failed')),
    prompt text,
    result_url text,
    error text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_media_jobs_user
ON public.media_jobs(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_media_jobs_story_scene
ON public.media_jobs(story_id, scene_id, media_type);

CREATE INDEX IF NOT EXISTS idx_media_jobs_status
ON public.media_jobs(status, created_at);

DROP TRIGGER IF EXISTS update_media_jobs_updated_at
ON public.media_jobs;
CREATE TRIGGER update_media_jobs_updated_at
    BEFORE UPDATE ON public.media_jobs
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.media_jobs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS media_jobs_own ON public.media_jobs;
CREATE POLICY media_jobs_own ON public.media_jobs
    FOR ALL USING (auth.uid() = user_id)
    WITH CHECK (
        auth.uid() = user_id
        AND story_id IN (SELECT id FROM public.stories WHERE user_id = auth.uid())
    );

-- Replace RAG search with story/user scoped filtering.
DROP FUNCTION IF EXISTS public.search_similar_characters(vector, double precision, integer);

CREATE OR REPLACE FUNCTION public.search_similar_characters(
    query_embedding vector(384),
    match_threshold float,
    match_count int,
    story_filter uuid DEFAULT null,
    user_filter uuid DEFAULT null
)
RETURNS TABLE(
    id uuid,
    name text,
    description text,
    similarity float
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.name,
        c.description,
        1 - (c.embedding <=> query_embedding) AS similarity
    FROM public.characters c
    WHERE c.embedding IS NOT NULL
      AND 1 - (c.embedding <=> query_embedding) > match_threshold
      AND (user_filter IS NULL OR c.user_id = user_filter)
      AND (
        story_filter IS NULL
        OR EXISTS (
            SELECT 1
            FROM public.story_characters sc
            WHERE sc.character_id = c.id
              AND sc.story_id = story_filter
        )
      )
    ORDER BY c.embedding <=> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;
