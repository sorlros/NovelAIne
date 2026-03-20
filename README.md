# 📖 NovelAIne (노벨라인)

<p align="center">
  <a href="README_EN.md">English</a> | 
  <a href="README_KR.md">한국어</a>
</p>

---

> **"Crafting immersive narrative experiences through intelligent context management and premium cinematic direction."**

NovelAIne is an AI-powered **interactive storytelling and automated illustration service**. We deliver a unique sense of immersion by combining RAG-based memory systems that prevent narrative inconsistencies even in long-form stories with premium UX features like fountain pen writing animations and real-time scene analysis.

---

## ✨ Key Features

### 🎭 Dynamic Character System
*   **Real-time Scene Analysis**: The LLM analyzes every scene to automatically display character cards for currently present or important figures.

### 🧠 Dual AI Engines
*   **Model Selection & Switching**: Seamlessly switch between speed-optimized `Gemini 2.0 Flash` and narrative-depth-focused `Gemini 1.5 Pro` at any time.

### ✒️ Premium Visual Direction
*   **Fountain Pen Animation**: Experience an analog touch with the `WritingEffect` that mimics a fountain pen writing on paper.
*   **Immersive View Modes**: Choose between **Manuscript Mode** (cinematic) and **Focus Mode** (minimalist).

### 🚀 High-Performance Hybrid Loading
*   **Background Pre-warming**: Recent stories are pre-parsed using **Isolates**, reducing loading times to near zero.
*   **Local Caching (Drift SQL)**: Implements a 'Zero-Latency' UI by fetching data from the local database (WASM supported).

### ⚡ Token Optimization & Cost Reduction
*   **English-Centric Prompting**: Maximizes reasoning performance and improves token efficiency by 2-3x.
*   **RAG-based Selective Memory**: Retrieves only relevant info via **Supabase pgvector**, drastically lowering costs.

---

## 🛠 Tech Stack

- **Frontend**: Flutter (Web & Mobile), Riverpod, Drift (SQL/WASM)
- **Backend**: FastAPI (Python), Supabase (PostgreSQL + pgvector)
- **AI**: OpenRouter (Gemini 2.0 Flash / 1.5 Pro), Stable Diffusion XL

---

## 🚀 Quick Start

### Frontend
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

### Backend
```bash
cd backend
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```

---

## 📅 Changelog
Check out latest updates in the [CHANGELOG.md](./CHANGELOG.md) file!
