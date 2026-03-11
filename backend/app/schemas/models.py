from pydantic import BaseModel, Field
from typing import Optional, List, Any
from datetime import datetime
from uuid import UUID


# ============================================
# USER MODELS
# ============================================
class UserBase(BaseModel):
    email: str
    username: Optional[str] = None
    avatar_url: Optional[str] = None


class UserCreate(UserBase):
    pass


class User(UserBase):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ============================================
# CHARACTER MODELS (RAG)
# ============================================
class CharacterBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: str = Field(..., min_length=1, max_length=2000)
    personality_traits: Optional[List[str]] = None
    background_story: Optional[str] = Field(None, max_length=5000)
    appearance_description: Optional[str] = Field(None, max_length=1000)
    image_url: Optional[str] = None


class CharacterCreate(CharacterBase):
    pass


class Character(CharacterBase):
    id: UUID
    user_id: UUID
    embedding: Optional[List[float]] = None  # Vector for RAG
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class StoryCharacterLink(BaseModel):
    character_id: UUID
    role_in_story: str = Field(
        default="supporting", pattern="^(protagonist|supporting|antagonist|npc)$"
    )


# ============================================
# STORY MODELS
# ============================================
class StoryBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    genre: str = Field(
        ..., pattern="^(fantasy|scifi|mystery|romance|horror|adventure)$"
    )
    description: Optional[str] = Field(None, max_length=2000)


class StoryCreate(BaseModel):
    title: Optional[str] = Field(None, max_length=200)  # Optional, can be generated
    genre: str = Field(..., pattern="^(fantasy|scifi|mystery|romance|horror|adventure|wuxia|apocalypse|cyberpunk|other)$")
    description: Optional[str] = Field(None, max_length=2000)
    # Generation params
    tone: Optional[str] = None
    protagonist_name: Optional[str] = None
    protagonist_traits: Optional[List[str]] = None
    protagonist_appearance_description: Optional[str] = Field(None, max_length=1000)
    opening_scenario: Optional[str] = None
    language: Optional[str] = "en_US"
    character_ids: Optional[List[UUID]] = None


class Story(StoryBase):
    id: UUID
    user_id: UUID
    status: str
    total_scenes: int
    current_scene_id: Optional[UUID] = None
    cover_image_url: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class StoryWithCharacters(Story):
    characters: List[Character] = []


# ============================================
# CHAPTER MODELS
# ============================================
class ChapterBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    sequence: int = Field(..., ge=1)


class ChapterCreate(ChapterBase):
    pass


class Chapter(ChapterBase):
    id: UUID
    story_id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ============================================
# CHOICE MODELS
# ============================================
class ChoiceBase(BaseModel):
    text: str = Field(..., min_length=1, max_length=500)
    consequence_summary: Optional[str] = Field(None, max_length=200)
    sequence: int = Field(..., ge=1)


class ChoiceCreate(ChoiceBase):
    pass


class Choice(ChoiceBase):
    id: UUID
    scene_id: UUID
    next_scene_id: Optional[UUID] = None
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================
# SCENE MODELS
# ============================================
class SceneBase(BaseModel):
    content: str = Field(..., min_length=1, max_length=10000)
    sequence: int = Field(..., ge=1)
    scene_type: str = Field(
        default="narrative", pattern="^(narrative|dialogue|choice|ending)$"
    )


class SceneCreate(SceneBase):
    choices: Optional[List[ChoiceCreate]] = None
    generate_image: bool = False
    generate_bgm: bool = False


class Scene(SceneBase):
    id: UUID
    story_id: UUID
    chapter_id: Optional[UUID] = None
    emotion_score: Optional[float] = None
    importance_score: Optional[float] = None
    has_generated_image: bool
    has_generated_bgm: bool
    current_choice_id: Optional[UUID] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class SceneWithChoices(Scene):
    choices: List[Choice] = []


class SceneScore(BaseModel):
    emotion_score: float = Field(..., ge=0, le=1)
    importance_score: float = Field(..., ge=0, le=1)
    should_generate_image: bool
    should_generate_bgm: bool


# ============================================
# MULTIMEDIA MODELS
# ============================================
class GeneratedImage(BaseModel):
    id: UUID
    scene_id: UUID
    prompt: str
    image_url: str
    model_used: str
    created_at: datetime

    class Config:
        from_attributes = True


class GeneratedBGM(BaseModel):
    id: UUID
    scene_id: UUID
    prompt: str
    audio_url: str
    mood: str
    duration_seconds: Optional[int] = None
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================
# USER PROGRESS MODELS
# ============================================
class UserProgressBase(BaseModel):
    current_scene_id: Optional[UUID] = None
    is_completed: bool = False


class UserProgressCreate(UserProgressBase):
    story_id: UUID


class UserProgress(UserProgressBase):
    id: UUID
    user_id: UUID
    story_id: UUID
    completed_scenes: List[UUID]
    choices_made: dict  # {scene_id: choice_id}
    last_read_at: datetime
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ============================================
# STORY GENERATION MODELS
# ============================================
class StoryGenerationRequest(BaseModel):
    story_id: UUID
    user_choice: Optional[str] = None  # User's free text input
    selected_choice_id: Optional[UUID] = None  # Or selected choice
    context_window: int = Field(default=5, ge=1, le=20)  # Previous scenes to include


class GeneratedSceneContent(BaseModel):
    content: str
    scene_type: str
    emotion_score: float
    importance_score: float
    choices: Optional[List[dict]] = None  # [{"text": "...", "consequence": "..."}]
    suggested_image_prompt: Optional[str] = None
    suggested_bgm_mood: Optional[str] = None


# ============================================
# API RESPONSE MODELS
# ============================================
T = type("T", (), {})


class ApiResponse(BaseModel):
    success: bool
    data: Optional[Any] = None
    error: Optional[str] = None
    meta: Optional[dict] = None

    @classmethod
    def ok(cls, data=None, meta=None):
        return cls(success=True, data=data, meta=meta)

    @classmethod
    def fail(cls, error: str):
        return cls(success=False, error=error)
