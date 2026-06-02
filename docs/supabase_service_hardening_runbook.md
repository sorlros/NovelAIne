# Supabase service_hardening_20260601 적용/검증/rollback Runbook

대상 SQL: `backend/database/service_hardening_20260601.sql`

이 문서는 운영 Supabase에 직접 적용하기 전/후 확인과 수동 복구 절차를 정의한다. Codex 로컬 작업에서는 실제 운영 DB에 적용하지 않는다.

## 1. 적용 전 확인

Supabase SQL Editor에서 아래 쿼리를 실행해 현재 상태를 기록한다.

```sql
select column_name, data_type, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'stories'
  and column_name in ('visibility', 'published_at', 'genre')
order by column_name;

select column_name, data_type, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'scenes'
  and column_name in ('role', 'image_url', 'bgm_url', 'client_request_id')
order by column_name;

select column_name, data_type, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'characters'
  and column_name = 'is_in_vault';

select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('story_comments', 'story_reactions', 'comment_reports', 'media_jobs')
order by table_name;

select indexname
from pg_indexes
where schemaname = 'public'
  and indexname in (
    'idx_stories_visibility',
    'idx_scenes_client_request_id',
    'idx_story_comments_story',
    'idx_story_reactions_story',
    'idx_comment_reports_comment',
    'idx_media_jobs_status'
  )
order by indexname;

select routine_name, data_type
from information_schema.routines
where specific_schema = 'public'
  and routine_name = 'search_similar_characters';
```

## 2. 적용 순서

1. Supabase Dashboard에서 대상 프로젝트와 환경을 확인한다.
2. SQL Editor에 `backend/database/service_hardening_20260601.sql` 전체를 붙여넣는다.
3. 하나의 transaction으로 실행 가능한지 확인한다. 실패 시 에러 위치를 기록하고 중단한다.
4. 성공 후 아래 적용 후 확인 쿼리를 실행한다.
5. 애플리케이션 API smoke test를 실행한다.

## 3. 적용 후 확인

```sql
select visibility, count(*)
from public.stories
group by visibility
order by visibility;

select count(*) as scenes_with_client_request_id
from public.scenes
where client_request_id is not null;

select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('story_comments', 'story_reactions', 'comment_reports', 'media_jobs')
order by table_name;

select policyname, tablename, cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('stories', 'scenes', 'choices', 'characters', 'story_comments', 'story_reactions', 'comment_reports', 'media_jobs')
order by tablename, policyname;

select indexname
from pg_indexes
where schemaname = 'public'
  and indexname like 'idx_%'
  and (
    indexname like '%stories_visibility%'
    or indexname like '%client_request_id%'
    or indexname like '%story_comments%'
    or indexname like '%story_reactions%'
    or indexname like '%comment_reports%'
    or indexname like '%media_jobs%'
  )
order by indexname;
```

RPC 확인:

```sql
select *
from public.search_similar_characters(
  array_fill(0.01::float, ARRAY[384])::vector(384),
  0.1,
  1,
  null,
  null
);
```

## 4. 애플리케이션 smoke test

- 로그인 후 내 stories 목록 조회
- 새 story 생성 후 첫 scene 저장 확인
- public story를 Explore/Community feed에서 조회
- 댓글 작성, 좋아요, 신고 누적 hidden 처리 확인
- media job 생성 후 `queued` 또는 `succeeded` 상태 확인
- 같은 `client_request_id`로 chat 재요청 시 중복 scene이 생기지 않는지 확인

## 5. Render health/readiness 확인

Render의 Health Check Path는 DB 연결을 수행하지 않는 `/healthz`로 설정한다.

```bash
curl -i "$BACKEND_URL/healthz"
```

정상 응답:

```json
{"status":"ok","service":"novelaine-backend"}
```

Supabase 포함 준비 상태는 `/readyz`로 별도 확인한다.

```bash
curl -i "$BACKEND_URL/readyz"
```

Supabase 연결이 정상일 때는 `{"status":"ready","database":"ready"}`를 반환한다. Supabase 521/502/503/504 등 일시 장애가 있으면 서버 liveness는 유지하고 `/readyz`만 `degraded`로 표시한다.

## 6. Rollback 또는 수동 복구

마이그레이션은 컬럼/테이블/RLS/인덱스를 추가하므로 자동 전체 rollback보다 수동 복구를 권장한다.

긴급 복구 순서:

```sql
-- 공개 노출 차단
update public.stories
set visibility = 'private'
where visibility = 'public';

-- media job 처리 중단
update public.media_jobs
set status = 'failed', error = 'Disabled by rollback procedure'
where status in ('queued', 'running', 'processing');

-- 커뮤니티 쓰기 정책 차단 예시
alter table public.story_comments disable row level security;
alter table public.story_reactions disable row level security;
alter table public.comment_reports disable row level security;
```

필요 시 추가 구조 rollback:

```sql
drop policy if exists story_comments_insert_own on public.story_comments;
drop policy if exists story_reactions_write_own on public.story_reactions;
drop policy if exists media_jobs_own on public.media_jobs;

drop table if exists public.comment_reports;
drop table if exists public.story_comments;
drop table if exists public.story_reactions;
drop table if exists public.media_jobs;
```

주의: 컬럼 drop은 데이터 손실을 유발하므로 운영에서는 백업 확인 후 수행한다.

## 7. 운영 주의사항

- 적용 전 DB backup 또는 Supabase point-in-time recovery 상태를 확인한다.
- `service_role` key가 서버 환경에만 존재하는지 확인한다.
- Storage bucket 정책이 이미지/BGM 공개 URL 정책과 맞는지 확인한다.
- 적용 후 API 로그에서 401/403/404/500 비율을 확인한다.
