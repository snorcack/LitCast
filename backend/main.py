from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.config import settings
from backend.api import websocket
from backend.api.routes import stream, episode
import logging

logging.basicConfig(level=settings.log_level)
logger = logging.getLogger(__name__)

app = FastAPI(title="LitCast Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(websocket.router)
app.include_router(stream.router)
app.include_router(episode.router)

@app.get("/health")
def health():
    return {"status": "ok", "version": "0.1.0"}
from backend.api.routes import debug
app.include_router(debug.router)
from backend.api.routes import session, library
app.include_router(session.router)
app.include_router(library.router)
from backend.api.routes import test_routes
app.include_router(test_routes.router)
