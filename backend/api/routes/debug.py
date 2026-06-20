from fastapi import APIRouter
from pydantic import BaseModel
from backend.memory.shared_context import SharedContext
import json

router = APIRouter(prefix="/session", tags=["debug"])
context = SharedContext()

class HeatRequest(BaseModel):
    session_id: str
    heat_level: float

@router.post("/heat")
async def override_heat(req: HeatRequest):
    data = await context.get(req.session_id)
    data["heat_level"] = req.heat_level
    await context.set(req.session_id, data)
    return {"status": "ok", "heat_level": req.heat_level}

@router.get("/{session_id}/debug")
async def get_session_debug(session_id: str):
    data = await context.get(session_id)
    return data
