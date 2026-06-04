-- Replace retired OpenRouter Gemini model ids with the current primary choices.
-- Run after reviewing affected rows in production.
--
-- Model policy:
-- - stories.llm_model stores the user's primary selected model only.
-- - Gemini runtime fallback is handled in backend/app/llm_models.py, not in DB rows.
-- - Primary fast: google/gemini-3.1-flash-lite -> fallback: qwen/qwen3.7-plus
-- - Primary pro: google/gemini-3.1-pro-preview -> fallback: minimax/minimax-m3

alter table public.stories
alter column llm_model set default 'google/gemini-3.1-flash-lite';

update public.stories
set llm_model = 'google/gemini-3.1-flash-lite'
where llm_model is null
   or llm_model = 'google/gemini-2.0-flash-001';

update public.stories
set llm_model = 'google/gemini-3.1-pro-preview'
where llm_model = 'google/gemini-pro-1.5';

-- Verification query for SQL Editor: confirms each stored primary model's runtime fallback.
select
    llm_model as primary_model,
    case llm_model
        when 'google/gemini-3.1-flash-lite' then 'minimax/minimax-m3'
        when 'google/gemini-3.1-pro-preview' then 'qwen/qwen3.7-plus'
        else null
    end as runtime_fallback_model,
    count(*) as story_count
from public.stories
group by llm_model
order by story_count desc, primary_model;
