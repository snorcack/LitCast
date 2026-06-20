import asyncio
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
from backend.crew.podcast_crew import PodcastCrew
from backend.crew.conversation_engine import ConversationEngine
from backend.memory.shared_context import SharedContext
import uuid

router = APIRouter(prefix="/session", tags=["session"])

class SessionStartRequest(BaseModel):
    book_title: str
    book_slug: str
    topic: str
    persona_ids: List[str]

running_engines = {}
context = SharedContext()

@router.post("/start")
async def start_session(req: SessionStartRequest):
    if not req.persona_ids or len(req.persona_ids) > 5:
        raise HTTPException(status_code=400, detail="Must have 1 to 5 personas")

    session_id = str(uuid.uuid4())

    await context.set(session_id, {
        "book_title": req.book_title,
        "book_slug": req.book_slug,
        "topic": req.topic,
        "segment": 1,
        "turns": [],
        "heat_level": 0.0,
        "interrupt_queue": [],
        "silence_counts": {pid: 0 for pid in req.persona_ids},
        "current_speaker": None,
        "status": "idle",
        "turn_count": 0
    })

    crew = PodcastCrew(session_id, req.book_title, req.topic, req.persona_ids)
    engine = ConversationEngine(session_id, crew, context)

    running_engines[session_id] = engine

    asyncio.create_task(engine.run())

    return {"session_id": session_id, "status": "running"}

class SessionActionRequest(BaseModel):
    session_id: str

@router.post("/stop")
async def stop_session(req: SessionActionRequest):
    if req.session_id not in running_engines:
        raise HTTPException(status_code=404, detail="Session not found")

    engine = running_engines[req.session_id]
    await engine.stop()
    del running_engines[req.session_id]

    return {"status": "stopped"}

@router.post("/pause")
async def pause_session(req: SessionActionRequest):
    if req.session_id not in running_engines:
        raise HTTPException(status_code=404, detail="Session not found")

    engine = running_engines[req.session_id]
    if engine.status == "running":
        await engine.pause()
        return {"status": "paused"}
    elif engine.status == "paused":
        await engine.resume()
        return {"status": "running"}
    else:
        return {"status": engine.status}
