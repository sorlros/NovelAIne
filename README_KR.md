# 📖 1인 개발 AI 대화형 소설 및 이미징 서비스

> **"효율적인 토큰 관리와 RAG 기술을 통해 몰입감 넘치는 서사 경험을 제공합니다."**

AI를 활용한 **대화형 소설 창작 및 자동 이미지 생성 서비스**입니다. 긴 호흡의 소설에서도 문맥을 잃지 않는 지능형 메모리 시스템과, 중요 장면을 시각화하는 이미지 생성 기술을 결합하여 독보적인 몰입감을 선사합니다.

---

## ✨ 주요 기능 (Key Features)

### 🧠 지능형 문맥 관리 (Intelligent Context Management)
*   **Summary Buffer Memory**: 최근 5~10턴의 대화는 원문 그대로 유지하고, 오래된 대화는 요약하여 저장함으로써 긴 소설 전개 시에도 문맥 끊김 없이 자연스러운 이야기를 이어갑니다.

### 📝 캐릭터 시트 시스템 (Character Sheet System)
*   **System Prompt Optimization**: 캐릭터의 성격, 외모, 배경 이야기를 시스템 프롬프트에 효율적으로 배치하여, 어떤 상황에서도 캐릭터의 일관성(Consistency)이 깨지지 않습니다.

### 📚 RAG 기반 기억 기술 (RAG-based Memory)
*   **Vector DB (Supabase pgvector)**: 방대한 세계관 설정이나 과거의 사건 중 현재 상황에 **꼭 필요한 정보만 벡터 검색으로 찾아내어** AI에게 제공합니다. 이를 통해 토큰 비용을 절감하면서도 깊이 있는 대화가 가능합니다.

### ⚡ 프롬프트 압축 (Prompt Compression)
*   **Efficiency First**: 불필요한 형용사나 미사여구를 제거하고, AI가 이해하기 쉬운 키워드 위주의 프롬프트 엔지니어링을 적용하여 응답 속도를 높이고 비용을 최소화했습니다.

### 🎨 장면 시각화 (Scene Visualization)
*   **Automatic Image Generation**: 소설의 텍스트를 실시간으로 분석하여 **'감정 점수(Emotion Score)'와 '중요도(Importance Score)'**를 산출합니다. 점수가 높은 결정적 순간에만 Stable Diffusion이 작동하여 극적인 삽화를 자동으로 생성합니다.

---

## 🛠 기술 스택 (Tech Stack)

### Backend
<p>
  <img src="https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi&logoColor=white"/>
  <img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white"/>
  <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white"/>
</p>

### Frontend
<p>
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=Flutter&logoColor=white"/>
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=Dart&logoColor=white"/>
</p>

### AI & Infrastructure
*   **LLM Model**: Groq (Llama-3.3-70b) - 초고속 추론
*   **Image Gen**: Stable Diffusion (via HuggingFace Inference API)
*   **Vector DB**: Supabase (pgvector extension)
*   **Package Management**: pub.dev (Flutter), pip (Python)

---

## 🚀 시작하기 (Getting Started)
더 자세한 설치 및 실행 방법은 `run_server.sh` 스크립트를 참고하거나 위키 문서를 확인해주세요.

---

## 📅 프로젝트 업데이트 내역 (Changelog)
새로운 기능, 버그 수정 및 UI/UX 디자인 개선 등 최신 변경 사항은 [CHANGELOG.md](./CHANGELOG.md) 파일에서 언제든지 확인하실 수 있습니다!
