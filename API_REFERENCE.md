# 📡 NovelAIne API Reference

This document summarizes the backend API endpoints.  
Automatic interactive documentation (Swagger UI) is available at: `http://localhost:8000/docs`

---

## 🟢 Base URL
`http://localhost:8000/api`

---

## 💬 Chat (AI Storyteller)

### `POST /chat`
Generates an AI response based on user input, context (Memory), and retrieved knowledge (RAG).

**Request:**
```json
{
  "message": "주인공은 누구야?"
}
```

**Response:**
```json
{
  "response": "당신은 이 이야기의 주인공 '지연'입니다..."
}
```

**Features:**
- **RAG Trigger**: Questions (e.g., "누구?", "왜?", "?") or long inputs (>20 chars) trigger vector search.
- **Memory**: Automatically buffers recent conversation history.

---

## 📖 Stories

### `GET /stories`
List all stories for the current user.

### `POST /stories`
Create a new story.

**Request:**
```json
{
  "title": "The Last Wizard",
  "genre": "fantasy",
  "description": "A story about..."
}
```

---

## 🎬 Scenes & Image Generation

### `POST /stories/{story_id}/scenes`
Create a new scene. **Triggers Image/BGM generation** based on content analysis.

**Request:**
```json
{
  "chapter_id": "uuid...",
  "content": "그녀는 절망적인 심정으로 울부짖었다. (슬픔)",
  "sequence": 1,
  "scene_type": "narrative"
}
```

**Response:**
```json
{
    "data": {
        "id": "uuid...",
        "content": "...",
        "emotion_score": 0.8,
        "importance_score": 0.2,
        "has_generated_image": true, 
        "has_generated_bgm": true
    }
}
```
> **Note**: If `has_generated_image` is true, the backend asynchronously generates an image and uploads it to Supabase Storage. The URL will be available in `generated_images` table linked to this `scene_id`.

---

## 👥 Characters

### `POST /characters`
Create a character profile. **This data is vectorized for RAG.**

**Request:**
```json
{
  "name": "지연",
  "description": "25세 바리스타. 밝은 갈색 머리에...",
  "personality_traits": ["cheerful", "clumsy"],
  "background_story": "서울에서 태어나..."
}
```

---

## 🛠 Setup & Auth
Currently, endpoints are open.  
Authentication middleware (Supabase Auth) will be added in future updates.
