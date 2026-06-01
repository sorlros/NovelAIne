# NovelAIne P0 베타 안정화 실행 계획

최종 업데이트: 2026-06-01
기준 커밋: `d5574c6 feat: harden MVP auth, community, media, and story persistence`

## 목표

NovelAIne MVP를 베타 검증 가능한 상태로 안정화한다. 이번 범위는 P0에 한정하며, P1/P2 신규 기능은 제외한다.

## P0 범위

1. Supabase `backend/database/service_hardening_20260601.sql` 적용/검증/rollback 문서화
2. backend auth, stories, scenes, community, media API contract 테스트 확대
3. 스트리밍 중단 복구를 위한 `client_request_id` 기반 재요청/복구 UX 보강
4. OpenRouter, HuggingFace 이미지/BGM, Supabase Storage timeout, rate limit, 실패 응답 표준화

## 제외 범위

- media worker 분리
- RAG 품질 고도화 및 embedding 재생성 정책 변경
- Explore 검색/정렬 고도화
- 관리자 moderation queue
- 결제/크레딧/알림 등 신규 제품 기능

## 완료 기준

- `docs/supabase_service_hardening_runbook.md`에 적용 전/후 확인 쿼리와 rollback 절차가 있다.
- backend contract 테스트가 외부 네트워크 없이 auth/stories/scenes/community/media 핵심 contract를 검증한다.
- stream 실패 시 프론트가 같은 `client_request_id`로 복구 요청할 수 있다.
- 외부 API 실패는 사용자 메시지와 내부 로그가 분리되고 media job 실패 상태가 표준화된다.
- 아래 검증이 통과한다.

```bash
PYTHONPATH=backend backend/venv/bin/python -m unittest discover backend/tests -v
python3 - <<'PY'
from pathlib import Path
files = [
    Path('backend/app/api/auth.py'),
    Path('backend/app/api/chat.py'),
    Path('backend/app/api/community.py'),
    Path('backend/app/api/media.py'),
    Path('backend/app/api/scenes.py'),
    Path('backend/app/api/stories.py'),
    Path('backend/app/services/audio_service.py'),
    Path('backend/app/services/chat_service.py'),
    Path('backend/app/services/image_service.py'),
    Path('backend/app/services/scene_service.py'),
    Path('backend/main.py'),
]
for file in files:
    compile(file.read_text(), str(file), 'exec')
print('python syntax ok')
PY
cd frontend && flutter analyze && flutter test
```

## 생성물 제외 기준

커밋 또는 최종 변경 요약 전 다음 항목을 제외 확인한다.

- `backend/venv/**`
- `**/__pycache__/**`
- Flutter build/cache 산출물
- 테스트 실행 중 생성된 임시 파일
