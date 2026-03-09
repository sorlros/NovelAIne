# NovelAIne 프론트엔드 아키텍처 분석

## 프로젝트 개요
NovelAIne은 Flutter 기반의 인터랙티브 스토리텔링 플랫폼으로, FastAPI 백엔드와 연결됩니다. 프론트엔드는 스토리 생성, 캐릭터 관리, AI 기반 스토리 생성 등의 풍부한 사용자 인터페이스를 제공합니다.

## 현재 구조 분석

### 프론트엔드 디렉토리 구조
```
frontend/
├── lib/
│   ├── core/
│   │   ├── constants.dart          # 전역 상수
│   │   └── theme/
│   │       └── app_theme.dart      # 앱 테마 설정
│   ├── data/
│   │   ├── models/
│   │   │   ├── creation_config.dart
│   │   │   └── story_model.dart
│   │   ├── services/
│   │   │   └── api_service.dart     # API 통신 계층
│   │   └── constants/
│   │       └── creation_prompts.dart
│   ├── presentation/
│   │   ├── providers/
│   │   │   └── chat_provider.dart    # 채팅 상태 관리
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   ├── auth_screen.dart
│   │   │   ├── story_screen.dart
│   │   │   ├── chat_screen.dart
│   │   │   ├── character_sheet_widget.dart
│   │   │   ├── wizard_screen.dart
│   │   │   └── mode_selection_screen.dart
│   │   └── profile/
│   │       ├── profile_screen.dart
│   │       └── widgets/
│   │           ├── user_header_widget.dart
│   │           ├── my_creations_tab.dart
│   │           └── my_library_tab.dart
│   └── main.dart
├── pubspec.yaml
└── test/
    └── widget_test.dart
```

### 백엔드 디렉토리 구조 (참조용)
```
backend/
├── app/
│   ├── api/
│   │   ├── chat.py
│   │   ├── stories.py
│   │   ├── scenes.py
│   │   └── characters.py
│   ├── schemas/
│   │   └── chat.py
│   └── services/
│       ├── chat_service.py
│       ├── story_service.py
│       └── rag_service.py
├── main.py
└── requirements.txt
```

## 기술 스택 분석

### 프론트엔드 기술
- **Flutter**: 크로스 플랫폼 모바일 앱 프레임워크
- **Dart**: 프로그래밍 언어
- **Provider**: 상태 관리 (현재)
- **HTTP Client**: API 통신용

### 백엔드 기술 (연동용)
- **FastAPI**: Python 웹 프레임워크
- **Pydantic**: 데이터 검증
- **PostgreSQL**: 데이터베이스 (Supabase 통해)
- **Groq API**: AI 스토리 생성

## 연동 지점

### API 엔드포인트 (백엔드 분석 기반)
- `GET /api/stories` - 스토리 목록
- `POST /api/stories` - 스토리 생성
- `GET /api/stories/{id}` - 스토리 상세
- `POST /api/chat` - AI 채팅 생성
- `POST /api/stories/{id}/scenes` - 장면 추가

### 인증
- JWT 기반 인증 (예상)
- 사용자 프로필 관리

## 현재 구현 평가

### 강점
- 관심사 분리 깔끔 (core/presentation/data)
- 적절한 위젯 구성
- 기본 API 서비스 계층 존재
- 테마 시스템 구축

### 개선 필요한 부분
- 제한된 에러 처리
- 포괄적인 상태 관리 부족
- API 엔드포인트 문서화 미비
- 캐싱 전략 부재
- 오프라인 지원 제한

## 프론트엔드-백엔드 협업 전략

### 데이터 흐름
1. 프론트엔드가 API 서비스를 통해 요청 전송
2. 백엔드가 요청 처리 후 JSON 반환
3. 프론트엔드가 데이터 검증 및 표시
4. 상태 관리가 UI 업데이트 처리

### 에러 처리
- 네트워크 에러
- 검증 에러
- API 속도 제한
- 인증 실패

### 성능 고려사항
- 대용량 스토리 데이터 지연 로딩
- 이미지 최적화
- 장시간 대화를 위한 메모리 관리

## 다음 단계 문서화

이 분석은 다음을 위해 사용됩니다:
1. 프론트엔드 개선 계획 수립
2. 신규 기능 설계
3. 적절한 백엔드 연동 보장
4. 포괄적인 문서화 생성

---
*문서 생성일: 2026-03-05*
*프론트엔드 개발자: [Your Name]*
*백엔드 협업: 진행 중*