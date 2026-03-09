-- =========================================================================
-- [NovelAIne] stories 테이블 장르 제약조건 확장 마이그레이션 SQL
-- 실행 위치: Supabase Dashboard -> SQL Editor
-- =========================================================================

-- 1. 기존의 제한적인 장르 제약조건(Check Constraint) 제거
ALTER TABLE public.stories
DROP CONSTRAINT IF EXISTS stories_genre_check;

-- 2. 새로운 장르들이 모두 포함된 넓은 범위의 제약조건 추가
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

-- (선택) 적용 후 확인용 쿼리
-- SELECT conname, pg_get_constraintdef(c.oid)
-- FROM pg_constraint c
-- JOIN pg_namespace n ON n.oid = c.connamespace
-- WHERE conname = 'stories_genre_check';
