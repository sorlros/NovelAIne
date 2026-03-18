# NovelAIne (노벨라인)

당신의 상상력이 현실이 되는 곳, AI 기반 인터랙티브 스토리텔링 플랫폼입니다.

## 🚀 주요 기능

- **다이내믹 캐릭터 시스템**: 실시간 장면 분석을 통해 현재 등장 중인 캐릭터를 카드로 노출하고 정보를 연동합니다.
- **AI 엔진 이원화**: Gemini 2.0 Flash와 1.5 Pro 모델 중 선택하여 속도와 서사의 깊이를 조절할 수 있습니다.
- **초고속 하이브리드 로딩**: Isolate 기반 사전 파싱 기술로 대량의 데이터도 지연 없이 즉시 로드합니다.
- **시네마틱 스토리텔링**: 몰입형 배경 시스템과 프리미엄 타이포그래피를 통한 독창적인 독서 경험.
- **멀티 플랫폼 캐싱**: Drift(SQL)를 활용한 웹(IndexedDB) 및 앱(SQLite) 데이터 보존 지원.

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
