# 📖 NovelAIne (노벨라인) - AI 대화형 소설 및 시각화 서비스

> **"지능형 문맥 관리와 프리미엄 연출을 통해 몰입감 넘치는 소설 창작 경험을 선사합니다."**

NovelAIne은 AI를 활용한 **인터랙티브 스토리텔링 및 자동 삽화 생성 서비스**입니다. 긴 호흡의 서사에서도 설정 오류를 방지하는 RAG 기반 메모리 시스템과, 만년필 필기 효과 및 실시간 장면 분석 등 프리미엄 UX 기술을 결합하여 독보적인 몰입감을 제공합니다.

---

## ✨ 핵심 기능 (Key Features)

### 🎭 다이내믹 캐릭터 시스템 (Dynamic Character Cards)
*   **실시간 장면 분석**: LLM이 장면을 분석하여 현재 등장 중인 캐릭터와 중요 인물을 UI에 자동으로 노출합니다. 인물의 퇴장과 등장을 시각적으로 관리하여 서사의 연속성을 돕습니다.

### 🧠 AI 스토리 엔진 이원화 (Dual AI Engines)
*   **모델 선택 및 전환**: 속도 중심의 `Gemini 2.0 Flash`와 치밀한 묘사 중심의 `Gemini 1.5 Pro`를 자유롭게 선택하고 이야기 도중 실시간으로 전환할 수 있습니다.

### ✒️ 프리미엄 시각 연출 (Premium Visual Effects)
*   **만년필 필기 애니메이션**: AI의 답변이 생성될 때 실제 종이에 만년필로 글을 쓰는 듯한 `WritingEffect`를 통해 아날로그적 감성을 제공합니다.
*   **몰입형 뷰 모드**: 삽화와 인물 정보를 강조하는 **원고 모드**와 텍스트 가독성에 집중한 **집중 모드**를 지원합니다.

### 🚀 초고속 하이브리드 로딩 (High-Performance Rendering)
*   **백그라운드 사전 파싱**: 메인 화면에서 최신 스토리를 **Isolate**로 미리 가공하여 화면 진입 시 대기 시간을 최소화했습니다.
*   **로컬 캐싱 시스템 (Drift SQL)**: 서버 응답을 기다리지 않고 로컬 DB에서 즉시 데이터를 읽어와 '제로 대기 시간' UI를 구현했습니다. **Drift(WASM)** 기술을 통해 웹과 모바일 모두에서 강력한 SQL 영속성을 제공합니다.
*   **스켈레톤 UI**: 로딩 중에도 사용자 경험을 저해하지 않도록 세련된 Shimmer 효과를 적용했습니다.

### 📚 RAG 기반 기억 기술 (RAG-based Memory)
*   **벡터 데이터베이스 (Supabase pgvector)**: 방대한 세계관 설정 중 현재 상황에 **꼭 필요한 정보만 벡터 검색**으로 찾아내어 AI에게 제공합니다. 이를 통해 일관성 있는 서사 전개가 가능합니다.

### 🎨 장면 시각화 (Scene Visualization)
*   **자동 삽화 생성**: 텍스트의 **'감정 점수'와 '중요도'**를 실시간 분석하여, 결정적인 순간에만 Stable Diffusion을 통해 극적인 삽화를 자동으로 생성합니다.

---

## ⚡ API 토큰 최적화 및 비용 절감 (Efficiency & Cost Reduction)

### 🧠 지능형 문맥 관리 (Intelligent Context Management)
*   **Summary Buffer Memory**: 최근 5~10턴의 대화는 원문 그대로 유지하고, 오래된 대화는 핵심 내용만 요약하여 저장합니다. 이를 통해 긴 소설 전개 시에도 토큰 낭비 없이 자연스러운 문맥을 이어갑니다.

### 📚 RAG 기반 선택적 기억 (RAG-based Selective Memory)
*   **Vector DB (Supabase pgvector)**: 방대한 세계관 설정이나 과거 사건 중 **현재 상황에 꼭 필요한 정보만 벡터 검색**으로 찾아내어 프롬프트에 주입합니다. 불필요한 정보 전송을 차단하여 비용을 획기적으로 절감합니다.
*   **Smart RAG Triggers**: 모든 입력에 RAG를 가동하는 대신, 질문(`?`), 문장 길이(25자 이상), 서사적 키워드(기억, 정체, 이동 등)를 감지하여 꼭 필요한 순간에만 지식을 검색합니다. 이를 통해 응답 속도를 높이고 불필요한 API 호출 비용을 절감합니다.

### ⚡ 프롬프트 압축 및 엔지니어링 (Prompt Compression)
*   **English-Centric Prompting**: 내부적으로 프롬프트를 **영문으로 최적화하여 전달**함으로써 LLM의 추론 성능을 극대화하고 한국어 대비 토큰 효율을 2~3배 높였습니다.
*   **Structural Keyword Division**: 문장 형태 대신 **구조화된 키워드 단위**로 정보를 전달하여 AI가 설정을 더 명확하게 이해하고 불필요한 서술 토큰을 낭비하지 않도록 설계했습니다.

### 🖼️ 선택적 이미지 생성 (Selective Image Generation)
*   **Scoring Logic**: 모든 장면에서 이미지를 생성하지 않고, 분석된 '중요도 점수'가 기준치를 넘는 **결정적 순간에만 AI 모델을 호출**하여 리소스를 효율적으로 관리합니다.

---

## 🛠 기술 스택 (Tech Stack)

### Frontend
- **Framework**: Flutter (Web & Mobile)
- **State Management**: Riverpod
- **Local Database**: Drift (SQL) with WASM (Web 지원)
- **Animation**: Flutter Animate, Custom Painters

### Backend
- **Framework**: FastAPI (Python)
- **Database**: Supabase (PostgreSQL + pgvector)
- **Authentication**: Supabase Auth (이메일/비밀번호)

### AI & Infrastructure
- **LLM**: OpenRouter (Gemini 2.0 Flash / 1.5 Pro)
- **Image Generation**: Stable Diffusion (via HuggingFace Inference)
- **Real-time**: HTTP Streaming (Line-splitter parsing)

---

## 📱 서비스 화면 구성

1.  **홈 화면**: 작성 중인 스토리 라이브러리 및 추천 테마.
2.  **창작 위저드**: 세계관 및 주인공 설정을 위한 3단계 프로세스.
3.  **스토리 화면**: 몰입형 창작 공간 (원고/집중 모드, 데스크탑 사이드 패널).
4.  **보관함**: 자주 사용하는 캐릭터 및 세계관 설정 관리.

---

## 🚀 시작하기

### Frontend
```bash
cd frontend
flutter pub get
flutter run -d chrome # 웹 실행 시
```

### Backend
```bash
cd backend
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```

---

## 📅 업데이트 내역 (Changelog)
새로운 기능 및 UI/UX 개선 사항은 [CHANGELOG.md](./CHANGELOG.md)에서 확인하실 수 있습니다.
