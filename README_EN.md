# 📖 Solo Dev AI Interactive Novel & Imaging Service

> **"Providing an immersive narrative experience through efficient token management and RAG technology."**

An AI-powered **interactive story creation and automated imaging service**. By combining an intelligent memory system that maintains context even in long-form stories with automated visualization of key scenes, we deliver a unique and immersive reading experience.

---

## ✨ Key Features

### 🧠 Intelligent Context Management
*   **Summary Buffer Memory**: Keeps the most recent 5-10 turns of dialogue verbatim while summarizing older interactions. This ensures a seamless narrative flow without losing context, even in long-running stories.

### 📝 Character Sheet System
*   **System Prompt Optimization**: Effectively embeds static character data (personality, appearance, background) into the system prompt, ensuring unwavering **Character Consistency** throughout the story.

### 📚 RAG-based Memory
*   **Vector DB (Supabase pgvector)**: Retrieves only the **most relevant information** from vast world settings or past events using vector search. This significantly reduces token costs while maintaining deep and context-aware interactions.

### ⚡ Prompt Compression
*   **Efficiency First**: Maximizes token efficiency by removing unnecessary fluff and using keyword-centric prompt engineering optimized for LLM comprehension.

### 🎨 Scene Visualization
*   **Automatic Image Generation**: Analyzes the narrative text in real-time to calculate **'Emotion Scores' and 'Importance Scores'**. Stable Diffusion is triggered only during pivotal moments with high scores to automatically generate dramatic illustrations.

---

## 🛠 Tech Stack

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
*   **LLM Model**: OpenRouter (Gemini 2.0 Flash) - High-performance/Context-efficient
*   **Image Gen**: Stable Diffusion (via HuggingFace Inference API)
*   **Vector DB**: Supabase (pgvector extension)
*   **Package Management**: pub.dev (Flutter), pip (Python)

---

## 🚀 Getting Started
For detailed installation and execution instructions, please refer to the `run_server.sh` script or check the Wiki.

---

## 📅 Changelog
You can always check the latest updates, bug fixes, and UI/UX design improvements in the [CHANGELOG.md](./CHANGELOG.md) file!
