from fastapi import APIRouter
from backend.llm.llm_router import get_llm_provider
from backend.tts.tts_router import get_tts_provider
from backend.llm.base_provider import LLMMessage

router = APIRouter(prefix="/test", tags=["test"])

@router.get("/providers")
async def test_providers():
    llm = get_llm_provider()
    tts = get_tts_provider()
    return {
        "llm": {
            "provider": llm.provider_name,
            "status": "ok"
        },
        "tts": {
            "provider": tts.provider_name,
            "status": "ok"
        }
    }
