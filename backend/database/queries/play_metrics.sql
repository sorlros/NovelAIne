-- Measurements for the switch to skeleton-mode stories (plan, chapter 12).
-- Run in the Supabase SQL Editor. Change the period in each query as needed.

-- 1. Does the prose change the state outside the brief? Read these pairs by hand:
--    the brief says who is alive, where, holding what; the scene must not change any of it
--    except through its '반드시' lines.
SELECT l.created_at, l.kind, l.brief, s.content AS scene
  FROM public.play_turn_log l
  JOIN public.scenes s ON s.id = l.scene_id
 WHERE l.outcome = 'saved' AND l.created_at > now() - interval '7 days'
 ORDER BY random()
 LIMIT 20;

-- 2. How often a turn replans the rest of its segment, and the delay it adds.
SELECT replanned, count(*) AS turns,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS percent,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY prepare_ms) AS median_prepare_ms,
       percentile_cont(0.9) WITHIN GROUP (ORDER BY prepare_ms) AS p90_prepare_ms
  FROM public.play_turn_log
 WHERE created_at > now() - interval '7 days'
 GROUP BY replanned;

-- 3. How often the reader had fewer than three choices.
SELECT count(*) FILTER (WHERE choices_offered < 3) AS short_turns, count(*) AS turns,
       round(100.0 * count(*) FILTER (WHERE choices_offered < 3) / nullif(count(*), 0), 1) AS percent
  FROM public.play_turn_log
 WHERE created_at > now() - interval '7 days';

-- 4. How often readers write their own action, and how those are judged.
SELECT kind, input_judgement, count(*) AS turns,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS percent
  FROM public.play_turn_log
 WHERE created_at > now() - interval '7 days'
 GROUP BY kind, input_judgement
 ORDER BY kind, input_judgement;

-- 5. Size of a turn: brief and scene length, and time to the first piece and to the end.
--    Exact tokens per model are in the OpenRouter activity page; divide by the turn count here.
SELECT model, count(*) AS turns,
       round(avg(length(brief))) AS avg_brief_chars, round(avg(prose_chars)) AS avg_prose_chars,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY first_chunk_ms) AS median_first_chunk_ms,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY stream_ms) AS median_stream_ms
  FROM public.play_turn_log
 WHERE outcome = 'saved' AND created_at > now() - interval '7 days'
 GROUP BY model;

-- Failures, for a quick look.
SELECT outcome, error, count(*)
  FROM public.play_turn_log
 WHERE outcome <> 'saved' AND created_at > now() - interval '7 days'
 GROUP BY outcome, error
 ORDER BY count(*) DESC;
