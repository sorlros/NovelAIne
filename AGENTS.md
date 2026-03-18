# NovelAIne AGENTS.md

AI-powered Interactive Storytelling Platform - Coding Standards & Guidelines

---

## Project Overview

**Tech Stack:**
- **Frontend**: Flutter (Dart)
- **Backend**: FastAPI (Python), Pydantic models
- **Database**: Supabase (PostgreSQL)
- **AI**: OpenRouter API (Gemini 2.0 Flash)
- **Deployment**: TBD

**Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│                      Frontend (Flutter)                     │
│  Dart + Flutter + Interactive UI Components                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Backend (FastAPI)                      │
│  Python 3.12 + FastAPI + Pydantic + OpenRouter             │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
        ┌──────────┐   ┌────────────┐   ┌──────────┐
        │ Supabase │   │ OpenRouter │   │  Vector  │
        │ Database │   │    API     │   │   Store  │
        │          │   │            │   │ (RAG)    │
        └──────────┘   └────────────┘   └──────────┘
```

---

## File Structure

```
NovelAIne/
├── frontend/                 # Flutter application
│   ├── lib/
│   │   ├── screens/         # UI screens
│   │   ├── widgets/         # Reusable widgets
│   │   ├── models/          # Data models
│   │   ├── services/        # API services
│   │   └── utils/           # Utilities
│   └── test/                # Flutter tests
│
├── backend/                  # FastAPI application
│   ├── app/
│   │   ├── api/            # API routes
│   │   │   └── chat.py     # Chat endpoints
│   │   ├── schemas/        # Pydantic models
│   │   │   └── chat.py
│   │   └── services/       # Business logic
│   ├── main.py             # FastAPI entry
│   └── tests/              # pytest tests
│
└── docs/                   # Documentation
```

---

## Coding Standards

### Python (FastAPI Backend)

#### Variable & Function Naming
```python
# ✅ GOOD: Descriptive names
market_search_query = "fantasy"
is_user_authenticated = True
total_scenes = 100

# ❌ BAD: Unclear names
q = "fantasy"
flag = True
x = 100
```

#### Function Naming
```python
# ✅ GOOD: Verb-noun pattern
async def fetch_story_data(story_id: str) -> Story:
    pass

def calculate_scene_score(scene: Scene) -> float:
    pass

def is_valid_choice(choice: Choice) -> bool:
    pass

# ❌ BAD: Unclear names
async def story(id: str):
    pass

def score(s):
    pass

def choice(c):
    pass
```

#### Type Safety with Pydantic
```python
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

# ✅ GOOD: Proper types
class Story(BaseModel):
    id: str
    title: str
    genre: "fantasy" | "scifi" | "mystery"
    status: "active" | "completed" | "archived"
    created_at: datetime
    
class Scene(BaseModel):
    id: str
    story_id: str
    content: str
    emotion_score: float
    importance_score: float
    choices: List[Choice]

# ❌ BAD: Using 'any' or no types
def get_story(id):  # No type hints
    pass
```

#### Error Handling
```python
from fastapi import HTTPException

# ✅ GOOD: Comprehensive error handling
async def fetch_scene(scene_id: str) -> Scene:
    try:
        response = await supabase
            .from("scenes")
            .select("*")
            .eq("id", scene_id)
            .single()
            .execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="Scene not found")
        
        return Scene(**response.data)
    except Exception as e:
        logger.error(f"Failed to fetch scene {scene_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch scene")

# ❌ BAD: No error handling
async def fetch_scene(scene_id: str):
    response = await supabase.from("scenes").select("*").eq("id", scene_id).execute()
    return response.data
```

#### Async/Await Best Practices
```python
# ✅ GOOD: Parallel execution when possible
scenes, characters, choices = await asyncio.gather(
    fetch_scenes(story_id),
    fetch_characters(story_id),
    fetch_choices(scene_id)
)

# ❌ BAD: Sequential when unnecessary
scenes = await fetch_scenes(story_id)
characters = await fetch_characters(story_id)
choices = await fetch_choices(scene_id)
```

### Dart (Flutter Frontend)

#### Variable Naming
```dart
// ✅ GOOD: Descriptive names
final String storyTitle = "Dragon's Quest";
final bool isLoading = false;
final int totalChoices = 3;

// ❌ BAD: Unclear names
final String t = "Dragon's Quest";
final bool flag = false;
final int n = 3;
```

#### Widget Structure
```dart
// ✅ GOOD: Clear widget structure with types
class StoryCard extends StatelessWidget {
  final Story story;
  final VoidCallback onTap;
  final bool isSelected;

  const StoryCard({
    required this.story,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(story.title),
        subtitle: Text(story.genre),
        onTap: onTap,
        selected: isSelected,
      ),
    );
  }
}

// ❌ BAD: No types, unclear structure
class StoryCard extends StatelessWidget {
  final story;
  
  StoryCard(this.story);
  
  @override
  Widget build(BuildContext context) {
    return Card(child: Text(story.title));
  }
}
```

#### State Management
```dart
// ✅ GOOD: Proper state updates
setState(() {
  _currentScene = newScene;
  _isLoading = false;
});

// ✅ GOOD: Functional update for collections
final updatedScenes = [..._scenes, newScene];
setState(() => _scenes = updatedScenes);

// ❌ BAD: Direct mutation
_scenes.add(newScene);  // BAD - mutates list directly
setState(() {});
```

---

## API Design Standards

### REST API Conventions (FastAPI)

```
GET    /api/stories              # List all stories
GET    /api/stories/:id          # Get specific story
POST   /api/stories              # Create new story
PUT    /api/stories/:id          # Update story (full)
PATCH  /api/stories/:id          # Update story (partial)
DELETE /api/stories/:id          # Delete story

GET    /api/stories/:id/scenes   # Get story scenes
POST   /api/stories/:id/scenes   # Add scene to story
POST   /api/chat                 # AI chat endpoint

# Query parameters for filtering
GET /api/stories?genre=fantasy&status=active&limit=10
```

### Response Format

```python
from pydantic import BaseModel
from typing import Generic, TypeVar, Optional

T = TypeVar('T')

class ApiResponse(BaseModel, Generic[T]):
    success: bool
    data: Optional[T] = None
    error: Optional[str] = None
    
    @classmethod
    def ok(cls, data: T) -> "ApiResponse[T]":
        return cls(success=True, data=data)
    
    @classmethod
    def fail(cls, error: str) -> "ApiResponse[T]":
        return cls(success=False, error=error)

# Success response
return {"success": True, "data": story, "meta": {"total": 100, "page": 1}}

# Error response
return {"success": False, "error": "Story not found"}
```

### Input Validation

```python
from pydantic import BaseModel, Field

class CreateStoryRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    genre: str = Field(..., pattern="^(fantasy|scifi|mystery|romance)$")
    description: str = Field(..., min_length=1, max_length=2000)

@router.post("/stories")
async def create_story(request: CreateStoryRequest):
    try:
        # request is already validated by Pydantic
        story = await story_service.create(request)
        return ApiResponse.ok(story)
    except Exception as e:
        return ApiResponse.fail(str(e))
```

---

## Database Patterns (Supabase)

### Query Optimization

```python
# ✅ GOOD: Select only needed columns
response = await supabase
    .from("scenes")
    .select("id, content, emotion_score, importance_score")
    .eq("story_id", story_id)
    .order("sequence", ascending=True)
    .limit(10)
    .execute()

# ❌ BAD: Select everything
response = await supabase
    .from("scenes")
    .select("*")
```

### N+1 Query Prevention

```python
# ❌ BAD: N+1 query problem
scenes = await fetch_scenes(story_id)
for scene in scenes:
    scene.choices = await fetch_choices(scene.id)  # N queries

# ✅ GOOD: Batch fetch
scenes = await fetch_scenes(story_id)
scene_ids = [s.id for s in scenes]
all_choices = await fetch_choices_for_scenes(scene_ids)  # 1 query

# Map choices to scenes
choices_map = {}
for choice in all_choices:
    if choice.scene_id not in choices_map:
        choices_map[choice.scene_id] = []
    choices_map[choice.scene_id].append(choice)

for scene in scenes:
    scene.choices = choices_map.get(scene.id, [])
```

---

## AI Integration Patterns

### OpenRouter API Integration

```python
import httpx
import os
import json

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

async def generate_story_segment(
    context: str,
    user_choice: str,
    character_profile: dict
) -> str:
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://novelaine.com",
        "X-Title": "NovelAIne",
    }
    
    payload = {
        "model": "google/gemini-2.0-flash-001",
        "messages": [
            {
                "role": "system",
                "content": f"You are an interactive storyteller. Character profile: {character_profile}"
            },
            {
                "role": "user",
                "content": f"Context: {context}\nUser choice: {user_choice}\nContinue the story..."
            }
        ],
        "temperature": 0.8,
        "max_tokens": 1000
    }
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(OPENROUTER_URL, headers=headers, json=payload, timeout=60.0)
            response.raise_for_status()
            result = response.json()
            return result["choices"][0]["message"]["content"]
    except Exception as e:
        logger.error(f"Story generation failed: {e}")
        raise
```

### Emotion Scoring Logic

```python
def calculate_scene_scores(scene_content: str) -> dict:
    """
    Calculate emotion and importance scores for scene.
    Used to determine if image/BGM should be generated.
    """
    # Keywords indicating emotional intensity
    emotion_keywords = ["death", "love", "betrayal", "victory", "tragedy"]
    importance_keywords = ["choice", "decision", "discovery", "revelation"]
    
    content_lower = scene_content.lower()
    
    emotion_score = sum(1 for kw in emotion_keywords if kw in content_lower) / len(emotion_keywords)
    importance_score = sum(1 for kw in importance_keywords if kw in content_lower) / len(importance_keywords)
    
    return {
        "emotion_score": min(emotion_score * 2, 1.0),  # Scale to 0-1
        "importance_score": min(importance_score * 2, 1.0),
        "should_generate_image": emotion_score > 0.5 or importance_score > 0.6
    }
```

---

## Error Handling Patterns

### Centralized Error Handler

```python
class ApiError(Exception):
    def __init__(self, status_code: int, message: str):
        self.status_code = status_code
        self.message = message

def error_handler(error: Exception) -> dict:
    if isinstance(error, ApiError):
        return {"success": False, "error": error.message}
    
    # Log unexpected errors
    logger.error(f"Unexpected error: {error}")
    return {"success": False, "error": "Internal server error"}

# Usage
@router.get("/stories/{story_id}")
async def get_story(story_id: str):
    try:
        story = await fetch_story(story_id)
        if not story:
            raise ApiError(404, "Story not found")
        return ApiResponse.ok(story)
    except Exception as e:
        return error_handler(e)
```

---

## Testing Standards

### Backend (pytest)

```bash
# Run all tests
pytest tests/

# Run with coverage
pytest tests/ --cov=. --cov-report=html

# Run specific test file
pytest tests/test_chat.py -v
```

**Test structure:**
```python
import pytest
from httpx import AsyncClient
from main import app

@pytest.fixture
async def client():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

@pytest.mark.asyncio
async def test_chat_endpoint(client: AsyncClient):
    response = await client.post(
        "/chat",
        json={"message": "Test message"}
    )
    assert response.status_code == 200
    assert response.json()["success"] is True
```

### Frontend (Flutter Tests)

```dart
// Widget test
void main() {
  testWidgets('StoryCard renders correctly', (WidgetTester tester) async {
    final story = Story(id: '1', title: 'Test Story', genre: 'fantasy');
    
    await tester.pumpWidget(
      MaterialApp(
        home: StoryCard(story: story, onTap: () {}),
      ),
    );
    
    expect(find.text('Test Story'), findsOneWidget);
    expect(find.text('fantasy'), findsOneWidget);
  });
}
```

---

## Critical Rules

1. **No emojis** in code, comments, or documentation
2. **Immutability** - never mutate objects or arrays directly
3. **Type safety** - use proper types everywhere (Pydantic for Python, strong types for Dart)
4. **Error handling** - all async operations must have try/catch
5. **Input validation** - validate all inputs with Pydantic/Zod
6. **No hardcoded secrets** - use environment variables
7. **Small functions** - keep functions under 50 lines
8. **Early returns** - avoid deep nesting with early returns
9. **Consistent naming** - follow naming conventions strictly
10. **Tests required** - write tests for all new features

---

## Environment Variables

```bash
# Backend (.env)
OPENROUTER_API_KEY=sk-or-v1-...
LLM_MODEL=google/gemini-2.0-flash-001
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_KEY=eyJ...
DATABASE_URL=postgresql://...

# Frontend (.env)
API_BASE_URL=http://localhost:8000
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
```

---

## Related Documentation

- `backend/README.md` - Backend setup and development
- `frontend/README.md` - Frontend setup and development
- `docs/architecture.md` - System architecture details
