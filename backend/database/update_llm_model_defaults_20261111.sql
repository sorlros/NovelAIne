-- Switch the story engines: low-cost DeepSeek V4.1 Flash, premium Claude Sonnet 5.5.
-- The API already treats the previous Gemini ids as the new engines (backend/app/llm_models.py);
-- this makes the stored values match, so the app shows the right engine as selected.
-- Safe to run more than once.

ALTER TABLE public.stories
ALTER COLUMN llm_model SET DEFAULT 'deepseek/deepseek-v4.1-flash';

UPDATE public.stories
SET llm_model = 'deepseek/deepseek-v4.1-flash'
WHERE llm_model IS NULL
   OR llm_model IN ('google/gemini-3.1-flash-lite', 'google/gemini-2.0-flash-001');

UPDATE public.stories
SET llm_model = 'anthropic/claude-sonnet-5.5'
WHERE llm_model IN ('google/gemini-3.1-pro-preview', 'google/gemini-pro-1.5');

-- What is stored now.
SELECT llm_model, count(*) AS stories
FROM public.stories
GROUP BY llm_model
ORDER BY stories DESC;
