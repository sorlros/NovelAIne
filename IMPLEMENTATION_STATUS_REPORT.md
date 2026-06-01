# NovelAIne 기능 구현율 및 완성도 점검 보고서

점검일: 2026-06-01
점검 기준: 현재 저장소의 실제 코드, DB 스키마, 마이그레이션 파일, 정적 분석 및 프론트 테스트 결과 기준

## 1. 전체 요약

| 구분 | 평가 |
| --- | --- |
| 전체 구현율 | 약 83% |
| 전체 완성도 | 약 74% |
| 현재 단계 | 핵심 MVP에서 베타 진입 전 단계 |
| 가장 완성도가 높은 영역 | Flutter 앱 구조, 스토리 생성 플로우, 인증 세션 복원/갱신, 공개 탐색, 스토리 읽기 UI |
| 최근 보강된 영역 | 사용자 토큰 기반 API 호출, refresh token 기반 세션 갱신, 서버 로그아웃 best-effort revoke, 스토리/장면 영속화, 공개 스토리 탐색, 커뮤니티 댓글/좋아요, BGM 생성/재생, 미디어 비동기 작업, 채팅 중복 저장 방지, 댓글 moderation, backend 자동 테스트, DB 스키마 정합성 |
| 남은 주요 리스크 | 실제 Supabase 마이그레이션 적용 여부, 외부 AI API 장애 대응, 운영용 미디어 worker 분리, backend 통합 테스트 부족 |

현재 NovelAIne은 AI 기반 첫 스토리 생성, 스트리밍 진행, 장면 저장, 캐릭터/RAG 기본 구조, 공개 탐색, 커뮤니티 반응, 장면별 BGM 생성/재생, 장시간 미디어 생성을 위한 job/polling 구조, 채팅 요청 중복 저장 방지, refresh token 기반 세션 갱신까지 연결된 MVP 수준입니다. 다만 실서비스 완성도를 위해서는 Supabase 마이그레이션 운영, 외부 API 실패 복구, backend API contract test 확대, 운영용 worker/queue, 세션 만료 UX 고도화가 추가로 필요합니다.

## 2. 기능별 구현율 및 완성도

| 기능 | 구현율 | 완성도 | 현재 상태 | 남은 작업 |
| --- | ---: | ---: | --- | --- |
| 프론트엔드 앱 구조 및 내비게이션 | 88% | 78% | Home, Explore, Create, Vault, Profile, Story, Community 화면과 반응형 레이아웃 구성 | 라우팅 체계 통합, 일부 중복 화면 정리 |
| 회원가입/로그인/세션 | 88% | 74% | Supabase Auth API, Flutter AuthProvider, 토큰 저장/복원, refresh token 갱신, API bearer header 전달, 서버 로그아웃 best-effort revoke 구현 | 세션 만료 UX, refresh 실패 시 사용자 안내 |
| 스토리 생성 위저드 | 84% | 70% | 장르/톤/주인공/모델 선택 후 AI로 title, description, first scene 생성 | 생성 실패 시 재시도/부분 롤백, 사용자 시나리오 입력 UI |
| AI 초기 스토리 생성 | 80% | 66% | OpenRouter 호출, JSON 파싱/복구, hero/ensemble 분기, 첫 장면 저장 | API rate limit 대응, 품질 평가 테스트, prompt 버전 관리 |
| 실시간 스토리 진행/채팅 | 82% | 69% | 일반/스트리밍 chat API, StoryScreen 스트리밍 UI, user/AI 턴 scene 저장, client_request_id 기반 중복 저장 방지 | 스트림 중단 복구, 장기 대화 테스트, 서버 동시성 부하 테스트 |
| 스토리/장면 CRUD | 78% | 66% | stories/scenes/choices CRUD, 권한 체크, sequence 자동 계산, image/bgm URL 필드 정리 | 마이그레이션 적용 자동화, 대량 장면 pagination |
| 캐릭터 시스템 | 76% | 62% | CRUD, 이미지 업로드, story 연결, user_id 검증, protagonist embedding 저장 | 수정 시 embedding 재생성, bucket 정책 점검 |
| 캐릭터 보관함 | 72% | 60% | `is_in_vault` 스키마와 Flutter Vault UI 연결 | 보관함 bulk 관리, 오프라인 동기화 정책 |
| RAG 기반 기억 | 68% | 56% | pgvector, HuggingFace embedding, story/user scoped search RPC, chat RAG 주입 | 검색 품질 평가, 트리거 고도화, 캐릭터 수정 시 embedding 갱신 |
| 장면 분석 및 인물 표시 | 70% | 58% | 장면 내 인물 분석 API와 프론트 표시 UX 구현 | 분석 결과 저장/캐싱, 실패 fallback 개선 |
| 이미지 생성/시각화 | 70% | 56% | 이미지 생성 API, Storage 업로드, scene image_url 저장, media_jobs 기반 비동기 생성 지원 | 실패 재시도, StoryScreen 배경 표시 최종 점검, 운영용 worker 분리 |
| BGM/오디오 | 76% | 62% | media_jobs 기반 BGM 생성, scene 저장, generated_bgms 기록, StoryScreen polling/수동 재생 UI 구현 | 운영용 worker 분리, 실제 브라우저 재생 호환성 QA |
| 로컬 캐시/성능 | 76% | 66% | Drift cache, scene prewarm, isolate parsing, schemaVersion 갱신 | 캐시 충돌 해결, 서버 저장 실패 시 재동기화 |
| 공개 탐색/공유 | 78% | 68% | 공개 스토리 API, visibility/published_at, Explore grid/list, read-only StoryScreen | 검색/정렬, 신고/차단, 공개 범위 세분화 |
| 커뮤니티 | 70% | 60% | 공개 스토리 feed, 댓글, 좋아요, counts, 댓글 삭제 UI, 신고 누적 숨김 moderation 구현 | pagination 고도화, 알림, 관리자 moderation queue |
| 테스트/QA/CI | 66% | 56% | `flutter analyze`, `flutter test`, backend unittest, Python syntax compile 통과 | pytest 전환, API contract test, 실제 Supabase fixture |
| 배포/운영 | 52% | 40% | Render/Vercel 관련 문서와 환경변수 구조 일부 존재 | 마이그레이션 절차, 모니터링, 장애 알림, secret rotation |

## 3. 핵심 기능 상세 점검

### 3.1 인증 및 권한

구현 파일:

- `backend/app/api/auth.py`
- `backend/app/services/auth_context.py`
- `frontend/lib/presentation/providers/auth_provider.dart`
- `frontend/lib/data/services/auth_session_store*.dart`
- `frontend/lib/data/services/api_service.dart`

평가:

- 로그인/회원가입 후 access token을 저장하고 앱 재시작 시 복원합니다.
- 만료 또는 만료 임박 세션은 refresh token으로 갱신하고, 갱신 실패 시 만료 전 토큰은 임시 유지하며 만료 후에는 세션을 정리합니다.
- 주요 API 요청에 `Authorization: Bearer` 헤더가 전달됩니다.
- API 호출 직전 저장된 세션을 확인해 장시간 웹/Android Web 사용 중 토큰 만료로 요청이 실패할 가능성을 줄였습니다.
- 로그아웃 시 클라이언트 세션을 정리하고 서버에 access token revoke를 best-effort로 요청합니다.
- stories, scenes, characters, chat, images API에서 서버 측 owner/read 접근 제어가 보강되었습니다.

남은 리스크:

- refresh 실패 시 사용자에게 재로그인 필요성을 명확히 안내하는 UX가 더 필요합니다.
- Supabase anon/service role 키 구성에 따라 서버 측 revoke 권한이 제한될 수 있습니다.

판정: 데모 수준을 넘어 사용자별 데이터 보호의 기본 골격은 갖췄습니다.

### 3.2 스토리 생성 및 진행 저장

구현 파일:

- `backend/app/api/stories.py`
- `backend/app/api/chat.py`
- `backend/app/api/scenes.py`
- `backend/app/services/scene_service.py`
- `frontend/lib/presentation/screens/story_screen.dart`

평가:

- AI가 생성한 첫 장면을 scene으로 저장하고 story의 current_scene_id/total_scenes를 갱신합니다.
- 일반 chat과 streaming chat 모두 user/AI turn을 scene으로 저장하는 구조가 추가되었습니다.
- scene sequence는 서버에서 다음 번호를 계산하도록 보강되었습니다.
- `client_request_id` 기반 idempotency로 동일 채팅 요청 재시도 시 중복 scene 저장을 줄였습니다.

남은 리스크:

- 스트리밍 중 네트워크가 끊겼을 때 partial 응답 저장/복구 정책이 더 필요합니다.
- 서버 동시성 부하 상황에서 idempotency unique index 적용 여부를 운영 DB에서 확인해야 합니다.

판정: 기존의 화면-only 스트리밍에서 지속 가능한 스토리 누적 구조로 개선되었습니다.

### 3.3 RAG 및 캐릭터 기억

구현 파일:

- `backend/app/services/rag_service.py`
- `backend/app/services/chat_service.py`
- `backend/database/schema.sql`
- `backend/database/service_hardening_20260601.sql`

평가:

- `characters.embedding vector(384)`와 `search_similar_characters` RPC가 있습니다.
- RAG 검색은 story_id/user_id 범위 필터를 지원합니다.
- 주인공 자동 생성 시 embedding 저장을 시도합니다.

남은 리스크:

- 독립 캐릭터 생성/수정 시 embedding 재생성 로직은 더 강화해야 합니다.
- RAG trigger가 아직 단순하며 품질 회귀 테스트가 없습니다.

판정: 아키텍처는 실제 서비스 방향에 맞지만 검색 품질 보증 단계는 남아 있습니다.

### 3.4 공개 탐색 및 커뮤니티

구현 파일:

- `backend/app/api/stories.py`
- `backend/app/api/community.py`
- `frontend/lib/presentation/screens/explore_screen.dart`
- `frontend/lib/presentation/screens/community_screen.dart`
- `frontend/lib/data/models/community_models.dart`

평가:

- public/private 공개 상태와 published_at 기반 공개 목록이 구현되었습니다.
- Explore에서 공개 작품을 읽기 전용으로 열 수 있습니다.
- Community feed에서 공개 작품의 좋아요 수, 댓글 수, 사용자 좋아요 상태를 표시합니다.
- 댓글 조회/작성/삭제, 좋아요/좋아요 취소, 댓글 신고 API와 모바일/웹 공통 UI가 연결되었습니다.
- 신고가 누적된 댓글은 `moderation_status=hidden`으로 전환되어 목록에서 제외됩니다.

남은 리스크:

- 차단 기능과 관리자 moderation queue는 아직 없습니다.
- 신고 임계값은 MVP 기준으로 단순 처리되어 있어 운영 정책 세분화가 필요합니다.
- 커뮤니티 테이블은 Supabase에 `service_hardening_20260601.sql`을 적용해야 실제 동작합니다.

판정: placeholder 단계에서 실제 상호작용 가능한 MVP로 올라왔습니다.

### 3.5 미디어 기능

구현 파일:

- `backend/app/api/images.py`
- `backend/app/api/media.py`
- `backend/app/services/image_service.py`
- `backend/app/services/audio_service.py`
- `backend/app/api/scenes.py`

평가:

- 이미지 생성/업로드와 scene image_url 저장 구조가 있습니다.
- BGM은 `media_jobs` 생성, Supabase Storage 업로드, scene `bgm_url` 저장, StoryScreen polling 기반 수동 재생 UI까지 연결되었습니다.

남은 리스크:

- 이미지/BGM 생성은 긴 작업이므로 앱 서버 `BackgroundTasks`보다 안정적인 운영용 worker/queue 분리가 필요합니다.
- 브라우저와 Android Web의 autoplay/audio permission 차이를 고려한 player UX가 필요합니다.

판정: 이미지와 BGM 모두 MVP 비동기 흐름은 갖췄지만, 다중 인스턴스 운영 환경에서는 별도 worker/queue로 분리해야 합니다.

## 4. DB 스키마 정합성

현재 코드 기대값과 `backend/database/schema.sql`, `backend/database/service_hardening_20260601.sql`은 주요 컬럼 기준으로 정렬되었습니다.

| 항목 | 현재 상태 | 주의점 |
| --- | --- | --- |
| stories.genre | 확장 장르 반영 | 기존 DB에는 마이그레이션 적용 필요 |
| stories.visibility/published_at | 공개 탐색용 컬럼 반영 | 공개 전환 시 published_at 갱신 |
| scenes.role/image_url/bgm_url/client_request_id | 장면 턴/미디어 저장 및 채팅 idempotency 필드 반영 | 기존 DB에는 마이그레이션 적용 필요 |
| characters.is_in_vault | 보관함 필드 반영 | 기존 DB에는 마이그레이션 적용 필요 |
| story_comments/story_reactions/comment_reports | 커뮤니티 댓글/반응/신고 테이블과 숨김 상태 추가 | 정책/인덱스 포함 마이그레이션 적용 필요 |
| media_jobs | 장시간 이미지/BGM 생성 작업 상태 저장 | 운영 DB에 마이그레이션 적용 필요 |
| search_similar_characters | story/user scoped signature 반영 | 기존 RPC 교체 필요 |

## 5. 검증 결과

### Backend

명령:

```bash
python3 - <<'PY'
from pathlib import Path
files = [
    Path('backend/app/api/community.py'),
    Path('backend/app/api/media.py'),
    Path('backend/app/api/audio.py'),
    Path('backend/app/api/chat.py'),
    Path('backend/app/api/scenes.py'),
    Path('backend/app/services/audio_service.py'),
    Path('backend/app/services/scene_service.py'),
    Path('backend/main.py'),
]
for file in files:
    compile(file.read_text(), str(file), 'exec')
print('python syntax ok')
PY
```

결과:

- 통과
- community/media/audio/scenes router와 main import의 Python 문법 오류는 발견되지 않았습니다.

추가 자동 테스트:

```bash
PYTHONPATH=backend backend/venv/bin/python -m unittest discover backend/tests -v
```

결과:

- backend unittest: 5 tests, OK
- idempotent chat turn 저장, client request id 중복 방지, 댓글 신고 숨김 threshold helper 검증

### Frontend

명령:

```bash
flutter analyze
flutter test
```

결과:

- `flutter analyze`: No issues found
- `flutter test`: All tests passed

주의:

- 이번 검증은 정적 분석과 Flutter 단위 테스트 중심입니다.
- 실제 Supabase, OpenRouter, HuggingFace 호출을 포함한 end-to-end 검증은 별도로 필요합니다.

## 6. 우선순위별 개선 권장안

### P0: 베타 안정화

1. Supabase 운영 DB에 `service_hardening_20260601.sql` 적용 및 rollback 절차 문서화
2. backend pytest 또는 unittest 기반 auth, stories, scenes, community API contract test 확대
3. 스트리밍 중단 후 재접속 시 마지막 응답 복구 UX와 서버 부하 테스트 추가
4. 외부 AI API timeout/rate limit/error별 사용자 메시지와 재시도 정책 정리

### P1: 제품 완성도 강화

1. 캐릭터 생성/수정 시 embedding 재생성 및 RAG 품질 테스트 추가
2. 커뮤니티 관리자 moderation queue, 신고 사유 분류, 알림 기능 추가
3. 공개 탐색 검색/정렬/페이지네이션 고도화
4. 로컬 캐시와 원격 데이터 충돌 해결 정책 추가

### P2: 미디어와 운영

1. 앱 서버 BackgroundTasks 기반 media_jobs를 운영용 worker/queue로 분리
2. Android Web과 Desktop Web에서 실제 기기 오디오 재생, 일시정지, 백그라운드 전환 QA
3. 배포 환경별 CORS/secret/Storage bucket 정책 점검
4. 장애 로그, request id, 비용 모니터링 추가

## 7. 최종 판단

NovelAIne은 현재 “AI로 스토리를 만들고, 사용자가 이어 쓰며, 결과가 중복 없이 저장되고, 공개된 작품에 반응을 남기고, 장면별 BGM을 job/polling 방식으로 생성해 수동 재생하는” MVP 핵심 흐름을 갖췄습니다. 실사용 베타로 올리기 위해서는 새 기능보다 운영 DB 마이그레이션 적용, backend API contract test 확대, 외부 API 장애 대응, 관리자 moderation queue, 운영용 미디어 worker 분리가 우선입니다.
