from fastapi import FastAPI
from dotenv import load_dotenv
from app.api.chat import router as chat_router
from app.api import stories, auth
from app.api.characters import router as characters_router
from app.api.scenes import router as scenes_router
from app.api.images import router as images_router
from app.api.community import router as community_router
from app.api.audio import router as audio_router
from app.api.media import router as media_router

load_dotenv()

app = FastAPI(title="NovelAIne API", version="0.1.0")

from fastapi.middleware.cors import CORSMiddleware

# CORS 설정
allow_origins = [
    "http://localhost:3000",
    "http://localhost:19006",
    "http://localhost:5000",
    "https://novelaine.vercel.app",  # 향후 Vercel 배포 시
    "*"  # 일단 개발 편의를 위해 유지하되, 추후 배포 도메인이 결정되면 특정합니다.
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
@app.head("/")
async def read_root():
    # Warm up Supabase connection on root request to mitigate cold start issues
    from app.services.supabase_client import check_connection
    is_db_ready = await check_connection()
    return {
        "status": "서버가 정상적으로 작동중", 
        "version": "0.1.0",
        "database": "ready" if is_db_ready else "initializing"
    }


app.include_router(chat_router, prefix="/api")
app.include_router(stories.router, prefix="/api")
app.include_router(auth.router, prefix="/api")
app.include_router(characters_router, prefix="/api")
app.include_router(scenes_router, prefix="/api")
app.include_router(images_router, prefix="/api")
app.include_router(community_router, prefix="/api")
app.include_router(audio_router, prefix="/api")
app.include_router(media_router, prefix="/api")
