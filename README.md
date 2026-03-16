# NovelAIne (노벨라인)

당신의 상상력이 현실이 되는 곳, AI 기반 인터랙티브 스토리텔링 플랫폼입니다.

## 🚀 주요 기능

- **시네마틱 스토리텔링**: 몰입형 배경 시스템과 프리미엄 타이포그래피를 통한 독창적인 독서 경험.
- **실시간 스트리밍**: AI의 답변을 기다림 없이 한 글자씩 실시간으로 감상 (Streaming Response).
- **멀티 플랫폼 캐싱**: Drift(SQL)를 활용한 웹(IndexedDB) 및 앱(SQLite) 오프라인 모드 지원.
- **자가 수리형 AI 엔진**: 복잡한 AI 응답도 안정적으로 파싱하여 끊김 없는 서사 제공.
- **마법의 서 로딩**: 이야기가 창조되는 과정을 시각화한 커스텀 애니메이션 UI.

## 🛠 기술 스택

### Frontend
- **Framework**: Flutter (Web & Mobile)
- **State Management**: Riverpod
- **Local Database**: Drift (SQL) with WASM
- **Animation**: Flutter Animate

### Backend
- **Framework**: FastAPI (Python)
- **Database**: Supabase (PostgreSQL)
- **LLM Engine**: Google Gemini 2.0 via OpenRouter
- **Real-time**: HTTP Streaming (StreamingResponse)

## 📦 시작하기

### Frontend
```bash
cd frontend
flutter pub get
flutter run -d chrome # 웹 실행
```

### Backend
```bash
cd backend
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```
