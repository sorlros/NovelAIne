-- NovelAIne Database Schema
-- Supabase PostgreSQL with pgvector extension for RAG

-- Enable pgvector extension for RAG (character embeddings)
create extension if not exists vector;

-- ============================================
-- USERS (Supabase Auth integration)
-- ============================================
create table users (
    id uuid references auth.users on delete cascade primary key,
    email text not null,
    username text unique,
    avatar_url text,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- ============================================
-- STORIES
-- ============================================
create table stories (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references users(id) on delete cascade not null,
    title text not null,
    genre text not null check (genre in ('fantasy', 'scifi', 'mystery', 'romance', 'horror', 'adventure', 'wuxia', 'apocalypse', 'cyberpunk', 'other')),
    description text,
    status text default 'active' check (status in ('active', 'completed', 'archived')),
    total_scenes integer default 0,
    current_scene_id uuid,
    cover_image_url text,
    llm_model text default 'google/gemini-3.1-flash-lite',
    narrative_type text default 'hero' check (narrative_type in ('hero', 'ensemble')),
    visibility text default 'private' check (visibility in ('private', 'public')),
    published_at timestamptz,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- ============================================
-- CHAPTERS
-- ============================================
create table chapters (
    id uuid default gen_random_uuid() primary key,
    story_id uuid references stories(id) on delete cascade not null,
    title text not null,
    sequence integer not null,
    description text,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    unique(story_id, sequence)
);

-- ============================================
-- SCENES (Story content units)
-- ============================================
create table scenes (
    id uuid default gen_random_uuid() primary key,
    story_id uuid references stories(id) on delete cascade not null,
    chapter_id uuid references chapters(id) on delete cascade,
    content text not null,
    sequence integer not null,
    role text default 'ai' check (role in ('user', 'ai', 'system')),
    client_request_id text,
    
    -- Scoring for multimedia generation
    emotion_score float check (emotion_score >= 0 and emotion_score <= 1),
    importance_score float check (importance_score >= 0 and importance_score <= 1),
    
    -- Multimedia flags
    has_generated_image boolean default false,
    has_generated_bgm boolean default false,
    image_url text,
    bgm_url text,
    
    -- Scene type for UI rendering
    scene_type text default 'narrative' check (scene_type in ('narrative', 'dialogue', 'choice', 'ending')),
    
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    unique(story_id, sequence)
);

-- ============================================
-- CHOICES (Branching paths)
-- ============================================
create table choices (
    id uuid default gen_random_uuid() primary key,
    scene_id uuid references scenes(id) on delete cascade not null,
    text text not null,
    next_scene_id uuid references scenes(id),
    consequence_summary text,
    sequence integer not null,
    created_at timestamptz default now(),
    unique(scene_id, sequence)
);

-- Update scenes to reference current choice
alter table scenes add column current_choice_id uuid references choices(id);

-- ============================================
-- CHARACTERS (For RAG consistency)
-- ============================================
create table characters (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references users(id) on delete cascade not null,
    name text not null,
    description text not null,
    personality_traits text[],
    background_story text,
    appearance_description text,
    image_url text,
    is_in_vault boolean default false,
    
    -- Vector embedding for RAG (using pgvector)
    -- Vector embedding for RAG (using pgvector)
    embedding vector(384),
    
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- ============================================
-- STORY_CHARACTERS (N:M relationship)
-- ============================================
create table story_characters (
    id uuid default gen_random_uuid() primary key,
    story_id uuid references stories(id) on delete cascade not null,
    character_id uuid references characters(id) on delete cascade not null,
    role_in_story text default 'supporting' check (role_in_story in ('protagonist', 'supporting', 'antagonist', 'npc')),
    created_at timestamptz default now(),
    unique(story_id, character_id)
);

-- ============================================
-- GENERATED_IMAGES
-- ============================================
create table generated_images (
    id uuid default gen_random_uuid() primary key,
    scene_id uuid references scenes(id) on delete cascade not null,
    prompt text not null,
    image_url text not null,
    storage_path text,
    model_used text default 'dall-e-3',
    generation_params jsonb,
    created_at timestamptz default now()
);

-- ============================================
-- GENERATED_BGMS
-- ============================================
create table generated_bgms (
    id uuid default gen_random_uuid() primary key,
    scene_id uuid references scenes(id) on delete cascade not null,
    prompt text not null,
    audio_url text not null,
    storage_path text,
    mood text not null,
    duration_seconds integer,
    created_at timestamptz default now()
);

-- ============================================
-- USER_PROGRESS (Track reading progress)
-- ============================================
create table user_progress (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references users(id) on delete cascade not null,
    story_id uuid references stories(id) on delete cascade not null,
    current_scene_id uuid references scenes(id),
    completed_scenes uuid[] default '{}',
    choices_made jsonb default '{}',
    is_completed boolean default false,
    last_read_at timestamptz default now(),
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    unique(user_id, story_id)
);

-- ============================================
-- COMMUNITY
-- ============================================
create table story_reactions (
    id uuid default gen_random_uuid() primary key,
    story_id uuid references stories(id) on delete cascade not null,
    user_id uuid references users(id) on delete cascade not null,
    reaction_type text default 'like' check (reaction_type in ('like')),
    created_at timestamptz default now(),
    unique(story_id, user_id, reaction_type)
);

create table story_comments (
    id uuid default gen_random_uuid() primary key,
    story_id uuid references stories(id) on delete cascade not null,
    user_id uuid references users(id) on delete cascade not null,
    content text not null check (char_length(trim(content)) between 1 and 1000),
    is_deleted boolean default false,
    report_count integer default 0,
    moderation_status text default 'visible' check (moderation_status in ('visible', 'hidden')),
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create table comment_reports (
    id uuid default gen_random_uuid() primary key,
    comment_id uuid references story_comments(id) on delete cascade not null,
    story_id uuid references stories(id) on delete cascade not null,
    reporter_id uuid references users(id) on delete cascade not null,
    reason text not null,
    created_at timestamptz default now(),
    unique(comment_id, reporter_id)
);

-- ============================================
-- MEDIA JOBS
-- ============================================
create table media_jobs (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references users(id) on delete cascade not null,
    story_id uuid references stories(id) on delete cascade not null,
    scene_id uuid references scenes(id) on delete cascade not null,
    media_type text not null check (media_type in ('image', 'bgm')),
    scene_type text default 'event' check (scene_type in ('dialogue', 'event')),
    status text default 'queued' check (status in ('queued', 'running', 'succeeded', 'failed')),
    prompt text,
    result_url text,
    error text,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- ============================================
-- INDEXES for performance
-- ============================================
create index idx_stories_user_id on stories(user_id);
create index idx_stories_genre on stories(genre);
create index idx_stories_status on stories(status);
create index idx_stories_visibility on stories(visibility, published_at desc);

create index idx_chapters_story_id on chapters(story_id);
create index idx_chapters_sequence on chapters(story_id, sequence);

create index idx_scenes_story_id on scenes(story_id);
create index idx_scenes_chapter_id on scenes(chapter_id);
create index idx_scenes_sequence on scenes(story_id, sequence);
create unique index idx_scenes_client_request_role
on scenes(story_id, client_request_id, role)
where client_request_id is not null;
create index idx_scenes_scores on scenes(emotion_score, importance_score);

create index idx_choices_scene_id on choices(scene_id);
create index idx_choices_next_scene on choices(next_scene_id);

create index idx_characters_user_id on characters(user_id);
create index idx_story_characters_story on story_characters(story_id);
create index idx_story_characters_character on story_characters(character_id);

create index idx_user_progress_user on user_progress(user_id);
create index idx_user_progress_story on user_progress(story_id);

create index idx_story_reactions_story on story_reactions(story_id);
create index idx_story_reactions_user on story_reactions(user_id);
create index idx_story_comments_story on story_comments(story_id, created_at desc);
create index idx_story_comments_user on story_comments(user_id);
create index idx_story_comments_moderation on story_comments(moderation_status, report_count);
create index idx_comment_reports_comment on comment_reports(comment_id);
create index idx_comment_reports_reporter on comment_reports(reporter_id);
create index idx_media_jobs_user on media_jobs(user_id, created_at desc);
create index idx_media_jobs_story_scene on media_jobs(story_id, scene_id, media_type);
create index idx_media_jobs_status on media_jobs(status, created_at);

-- Vector index for RAG similarity search
create index idx_characters_embedding on characters using ivfflat (embedding vector_cosine_ops);

-- ============================================
-- TRIGGERS for updated_at
-- ============================================
create or replace function update_updated_at_column()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger update_users_updated_at before update on users
    for each row execute function update_updated_at_column();

create trigger update_stories_updated_at before update on stories
    for each row execute function update_updated_at_column();

create trigger update_chapters_updated_at before update on chapters
    for each row execute function update_updated_at_column();

create trigger update_scenes_updated_at before update on scenes
    for each row execute function update_updated_at_column();

create trigger update_characters_updated_at before update on characters
    for each row execute function update_updated_at_column();

create trigger update_user_progress_updated_at before update on user_progress
    for each row execute function update_updated_at_column();

create trigger update_story_comments_updated_at before update on story_comments
    for each row execute function update_updated_at_column();

create trigger update_media_jobs_updated_at before update on media_jobs
    for each row execute function update_updated_at_column();

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================
alter table users enable row level security;
alter table stories enable row level security;
alter table chapters enable row level security;
alter table scenes enable row level security;
alter table choices enable row level security;
alter table characters enable row level security;
alter table story_characters enable row level security;
alter table generated_images enable row level security;
alter table generated_bgms enable row level security;
alter table user_progress enable row level security;
alter table story_reactions enable row level security;
alter table story_comments enable row level security;
alter table comment_reports enable row level security;
alter table media_jobs enable row level security;

-- Users: can only read/update own profile
create policy users_own_profile on users
    for all using (auth.uid() = id);

-- Stories: users can CRUD own stories, public can read published
create policy stories_own_stories on stories
    for all using (auth.uid() = user_id);

create policy stories_public_read on stories
    for select using (visibility = 'public');

-- Chapters: accessible through story ownership
create policy chapters_via_story on chapters
    for all using (story_id in (select id from stories where user_id = auth.uid()));

-- Scenes: accessible through story ownership
create policy scenes_via_story on scenes
    for all using (story_id in (select id from stories where user_id = auth.uid()));

create policy scenes_public_read on scenes
    for select using (
        story_id in (select id from stories where visibility = 'public')
    );

-- Choices: accessible through scene ownership
create policy choices_via_scene on choices
    for all using (scene_id in (
        select s.id from scenes s 
        join stories t on s.story_id = t.id 
        where t.user_id = auth.uid()
    ));

create policy choices_public_read on choices
    for select using (scene_id in (
        select s.id from scenes s
        join stories t on s.story_id = t.id
        where t.visibility = 'public'
    ));

-- Characters: users can CRUD own characters
create policy characters_own on characters
    for all using (auth.uid() = user_id);

create policy characters_public_story_read on characters
    for select using (id in (
        select sc.character_id
        from story_characters sc
        join stories t on sc.story_id = t.id
        where t.visibility = 'public'
    ));

-- Story Characters: accessible through story ownership
create policy story_characters_via_story on story_characters
    for all using (story_id in (select id from stories where user_id = auth.uid()));

create policy story_characters_public_read on story_characters
    for select using (
        story_id in (select id from stories where visibility = 'public')
    );

-- Generated Images: accessible through scene ownership
create policy images_via_scene on generated_images
    for all using (scene_id in (
        select s.id from scenes s 
        join stories t on s.story_id = t.id 
        where t.user_id = auth.uid()
    ));

-- Generated BGMs: accessible through scene ownership
create policy bgms_via_scene on generated_bgms
    for all using (scene_id in (
        select s.id from scenes s 
        join stories t on s.story_id = t.id 
        where t.user_id = auth.uid()
    ));

-- User Progress: users can CRUD own progress
create policy user_progress_own on user_progress
    for all using (auth.uid() = user_id);

-- Story Reactions: public story readers can read reactions, authenticated users can react
create policy story_reactions_read_public on story_reactions
    for select using (
        story_id in (
            select id from stories
            where visibility = 'public' or user_id = auth.uid()
        )
    );

create policy story_reactions_write_own on story_reactions
    for all using (auth.uid() = user_id)
    with check (
        auth.uid() = user_id
        and story_id in (
            select id from stories
            where visibility = 'public' or user_id = auth.uid()
        )
    );

-- Story Comments: public story readers can read comments, authenticated users can write comments
create policy story_comments_read_public on story_comments
    for select using (
        is_deleted = false
        and story_id in (
            select id from stories
            where visibility = 'public' or user_id = auth.uid()
        )
    );

create policy story_comments_insert_own on story_comments
    for insert with check (
        auth.uid() = user_id
        and story_id in (
            select id from stories
            where visibility = 'public' or user_id = auth.uid()
        )
    );

create policy story_comments_delete_own_or_story_owner on story_comments
    for delete using (
        auth.uid() = user_id
        or story_id in (select id from stories where user_id = auth.uid())
    );

-- Comment Reports: authenticated public-story readers can create one report per comment
create policy comment_reports_own on comment_reports
    for all using (auth.uid() = reporter_id)
    with check (
        auth.uid() = reporter_id
        and story_id in (
            select id from stories
            where visibility = 'public' or user_id = auth.uid()
        )
    );

-- Media Jobs: users can manage jobs for their own stories
create policy media_jobs_own on media_jobs
    for all using (auth.uid() = user_id)
    with check (
        auth.uid() = user_id
        and story_id in (select id from stories where user_id = auth.uid())
    );

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Increment story scene count
create or replace function increment_story_scene_count(story_id uuid)
returns void as $$
begin
    update stories
    set total_scenes = total_scenes + 1
    where id = story_id;
end;
$$ language plpgsql;

-- Decrement story scene count
create or replace function decrement_story_scene_count(story_id uuid)
returns void as $$
begin
    update stories
    set total_scenes = greatest(total_scenes - 1, 0)
    where id = story_id;
end;
$$ language plpgsql;

-- Search characters by similarity (RAG)
create or replace function search_similar_characters(
    query_embedding vector(384),
    match_threshold float,
    match_count int,
    story_filter uuid default null,
    user_filter uuid default null
)
returns table(
    id uuid,
    name text,
    description text,
    similarity float
) as $$
begin
    return query
    select
        c.id,
        c.name,
        c.description,
        1 - (c.embedding <=> query_embedding) as similarity
    from characters c
    where 1 - (c.embedding <=> query_embedding) > match_threshold
      and c.embedding is not null
      and (user_filter is null or c.user_id = user_filter)
      and (
        story_filter is null
        or exists (
            select 1 from story_characters sc
            where sc.character_id = c.id
              and sc.story_id = story_filter
        )
      )
    order by c.embedding <=> query_embedding
    limit match_count;
end;
$$ language plpgsql;
