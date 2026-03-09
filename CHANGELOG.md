# Changelog (작업 내역)

이 파일은 NovelAIne 프로젝트의 개발 과정에서 수정되거나 추가된 주요 작업 내역을 갱신하기 위해 자동 유지보수되는 페이지입니다.

## [2026-03] UI/UX 개선 및 버그 수정 (현재 진행 중)

### 🐛 버그 수정 (Bug Fixes)
- **POST `/api/stories` Internal Server Error 해결**: 백엔드에서 인증 없이 임시(Guest) 스토리를 생성할 때 `public.users`의 외래키 테이블(`auth.users`) 연동 제약조건에 걸려 `user_id`를 임의로 부여할 수 없던 문제를 확인했습니다. 우회책으로 데모용 정식 테스트 계정(`novelaineguest@gmail.com`)을 파이프라인에 주입하여 DB 구멍을 메우고 에러(500)를 해결했습니다.
- **POST `/api/stories` 422 에러 수정**: 프론트엔드 UI의 한글 장르명("판타지 (Fantasy)")과 백엔드 정규식(`^(fantasy...)$`) 검증 불일치 문제 해결. 프론트엔드 `ApiService`에 `_mapGenreToBackend` 변환 로직 추가.
- **이미지 생성 서버 오류 해결**: Hugging Face 최신 애니메이션 향상 모델(`cagliostrolab/animagine-xl-3.1`)로 텍스트 투 이미지(Text-to-Image) 로직 교체 및 프론트 통신(임시 이미지 삭제) 연동.
- **`aiocache` 모듈 에러**: 사용하지 않는 `aiocache` 모듈이 `image_service.py`에 임포트 되어 서버 크래시를 유발하던 문제 임포트 라인 삭제로 조치.

### 💄 UI/UX 및 렌더링 오버플로우(Bottom Overflowed) 해결
- **`AuthScreen` (로그인/가입 화면)**: 고정 높이 할당을 제거하고 화면 크기와 키보드 호출에 맞춰 유연하게(`Flexible/Expanded`) 늘어나도록 수정.
- **`ProfileScreen` (프로필/서재 화면)**: 헤더와 탭 뷰가 자연스럽게 동작하도록 `NestedScrollView` 구조로 전면 교체.
- **`HomeScreen` (메인 홈)**: 횡스크롤 이야기 카드의 높이를 420px에서 여유있게 440px로 늘려 제목과 내용 텍스트 오버플로우 방지.
- **`Creation Wizard` (스토리 생성 마법사)**:
  - `ModeSelectionScreen` 위젯에 `SingleChildScrollView` 래핑을 추가하여 작은 기기에서 버튼이 잘리는 현상 해결.
  - `WorldStep` 및 `CharacterStep`에서 키보드를 띄울 시 화면이 충돌하는 문제를 막기 위해 `Column`을 `ListView`로 교체하고 `SafeArea` 및 `resizeToAvoidBottomInset` 적용.

### 🌟 신규 기능 및 구조 개선 (Features)
- **Phase 11 (감각적 확장 - BGM 및 뷰티파이 연동)**:
  - 백엔드에 `AudioService` 신설. HuggingFace `facebook/musicgen-small` LLM을 이용해 씬(Scene)의 감정을 분석하여 실시간 배경음(BGM)을 합성 및 반환하는 파이프라인 개발.
  - 백엔드 `ImageService` 강화. `generate_anime_image` 파이프라인에 캐릭터 외모 주입 로직(`character_appearance`)을 필수 Parameter로 추가하여 이미지 생성 시마다 얼굴과 옷차림이 변경되는 문제를 방지.
  - 프론트엔드 `story_screen`에서 AI의 BGM URL 응답을 실시간 캐싱하고 `audioplayers` 모듈로 자동 재생.
- **프롬프트 압축 및 토큰 최적화 (Prompt Compression)**: 유저가 챗(이야기 전개) 화면에서 입력하는 긴 한국어 지시문을 서브 LLM을 통해 영문 키워드로 1차 압축(`_compress_to_english_keywords`)한 뒤 메인 모델에 전송하는 파이프라인 개통. 토큰 누적 낭비를 막고 추론 비용을 대폭 절감. (응답은 한국어로 강제 유지)
- **멀티 에이전트 오케스트레이션(Global Multi-Agent)**: `~/.agents/` 폴더 하위에 각 직군별(PM, Backend, Frontend, UI/UX) `SKILL`을 분리하고 `/orchestrate` 명령을 통한 자율 협업 파이프라인 개통.
- **자율 Git 형상관리 (Orchestration Bot)**: 개발 에이전트가 단일 태스크 완료 시 자동으로 `feature/` 브랜치를 생성하고 커밋 이력을 남기도록 워크플로우에 Git CI 편입.

---

*[위 내용은 에이전트의 작업 진행 시마다 지속적으로 업데이트 됩니다]*
