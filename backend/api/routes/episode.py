from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
from pathlib import Path

router = APIRouter(prefix="/episode", tags=["episode"])

@router.get("/{session_id}")
async def get_episode(session_id: str):
    path = Path("episodes") / f"{session_id}.mp3"
    if not path.exists():
        raise HTTPException(status_code=404, detail="Episode not found")
    return FileResponse(path, media_type="audio/mpeg", filename=f"{session_id}.mp3")
