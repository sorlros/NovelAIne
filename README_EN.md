# 📖 NovelAIne - AI Interactive Storytelling & Visualization Service

<p align="center">
  <a href="README.md">한국어</a> | <b>English</b>
</p>

---

> **"Crafting immersive narrative experiences through intelligent context management and premium cinematic direction."**

NovelAIne is an AI-powered **interactive storytelling and automated illustration service**. We deliver a unique sense of immersion by combining RAG-based memory systems that prevent narrative inconsistencies even in long-form stories with premium UX features like fountain pen writing animations and real-time scene analysis.

---

## ✨ Key Features

### 🎭 Dynamic Character System
*   **Real-time Scene Analysis**: The LLM analyzes every scene to automatically display character cards for currently present or important figures. It visually manages character entries and exits to ensure narrative continuity.

### 🧠 Dual AI Engines
*   **Model Selection & Switching**: Seamlessly switch between speed-optimized `Gemini 2.0 Flash` and narrative-depth-focused `Gemini 1.5 Pro` at any time during your story.

### ✒️ Premium Visual Direction
*   **Fountain Pen Animation**: Experience an analog touch with the `WritingEffect` that mimics a fountain pen writing on paper as AI responses are generated.
*   **Immersive View Modes**: Choose between **Manuscript Mode** (highlighting illustrations and character cards) and **Focus Mode** (a minimalist view optimized for reading text).

### 🚀 High-Performance Hybrid Loading
*   **Background Pre-warming**: Recent stories are pre-parsed using **Isolates** on the home screen, reducing loading times to near zero when entering a story.
*   **Local Caching (Drift SQL)**: Implements a 'Zero-Latency' UI by fetching data from the local database before server synchronization. Leveraging **Drift (WASM)**, we provide powerful SQL persistence and data integrity across both Web and Mobile platforms.
*   **Shimmer UI**: Sophisticated skeleton loading effects maintain a premium feel even during data retrieval.

### 📚 RAG-based Memory
*   **Vector Database (Supabase pgvector)**: Uses **vector search** to retrieve only the most relevant information from vast world-building data or past events, ensuring unwavering narrative consistency.

### 🎨 Scene Visualization
*   **Automated Illustration**: Real-time analysis of **'Emotion' and 'Importance' scores** triggers Stable Diffusion to generate dramatic illustrations only for pivotal moments.

---

## ⚡ Token Optimization & Cost Reduction

### 🧠 Intelligent Context Management
*   **Summary Buffer Memory**: Maintains recent 5-10 dialogue turns verbatim while summarizing older interactions into concise bullet points. This ensures narrative continuity across long stories without bloating token usage.

### 📚 RAG-based Selective Memory
*   **Vector Database (Supabase pgvector)**: Uses **vector search** to retrieve only the most relevant world-building data or past events for the current context. By injecting only necessary information into the prompt, it significantly lowers operational costs.

### ⚡ Prompt Compression & Engineering
*   **English-Centric Prompting**: By internally **optimizing prompts in English**, we maximize the LLM's reasoning performance and improve token efficiency by 2-3x compared to Korean-only prompts.
*   **Structural Keyword Division**: Information is delivered in **structured keyword blocks** rather than natural language sentences. This ensures the AI understands world settings more clearly while eliminating token waste from redundant descriptions.

### 🖼️ Selective Image Generation
*   **Scoring Logic**: Instead of generating images for every scene, our system analyzes 'Importance Scores' and only calls image models for **defining narrative moments**, ensuring optimal resource allocation.

---

## 🛠 Tech Stack

### Frontend
- **Framework**: Flutter (Web & Mobile)
- **State Management**: Riverpod
- **Local Database**: Drift (SQL) with WASM (for Web support)
- **Animation**: Flutter Animate, Custom Painters

### Backend
- **Framework**: FastAPI (Python)
- **Database**: Supabase (PostgreSQL + pgvector)
- **Authentication**: Supabase Auth (Email/Password)

### AI & Infrastructure
- **LLM**: OpenRouter (Gemini 2.0 Flash / 1.5 Pro)
- **Image Generation**: Stable Diffusion (via HuggingFace Inference)
- **Real-time**: HTTP Streaming (Line-splitter parsing)

---

## 📱 Service Screens

1.  **Home Screen**: Story library and recommended genre themes.
2.  **Creation Wizard**: A 3-step process for world-building and character setup.
3.  **Story Screen**: Immersive creative space (Manuscript/Focus modes, Desktop side panel).
4.  **Character Vault**: Management of frequently used characters and world settings.

---

## 🚀 Getting Started

### Frontend
```bash
cd frontend
flutter pub get
flutter run -d chrome # To run on web
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
Check out latest features and UI/UX improvements in the [CHANGELOG.md](./CHANGELOG.md) file!
