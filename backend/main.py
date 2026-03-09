from fastapi import FastAPI
from dotenv import load_dotenv
from app.api.chat import router as chat_router
from app.api import stories, auth
from app.api.characters import router as characters_router
from app.api.scenes import router as scenes_router
from app.api.images import router as images_router

load_dotenv()

app = FastAPI(title="NovelAIne API", version="0.1.0")

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def read_root():
    return {"status": "서버가 정상적으로 작동중", "version": "0.1.0"}


app.include_router(chat_router, prefix="/api")
app.include_router(stories.router, prefix="/api")
app.include_router(auth.router, prefix="/api")
app.include_router(characters_router, prefix="/api")
app.include_router(scenes_router, prefix="/api")
app.include_router(images_router, prefix="/api")
