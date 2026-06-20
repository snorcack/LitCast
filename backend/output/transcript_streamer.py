import json
import base64
import redis.asyncio as aioredis
from backend.config import settings
from backend.agents.base_agent import AgentTurn

class TranscriptStreamer:
    def __init__(self):
        self.redis = aioredis.from_url(settings.redis_url)

    async def emit(self, turn: AgentTurn, audio_bytes: bytes, session_id: str):
        payload = {
            "type": "turn",
            "speaker": turn.speaker,
            "text": turn.text,
            "color_hex": turn.color_hex,
            "audio_b64": base64.b64encode(audio_bytes).decode("utf-8") if audio_bytes else None,
            "rag_passages": turn.rag_passages,
            "timestamp": turn.timestamp
        }
        await self.redis.publish(f"session:{session_id}:events", json.dumps(payload))

    async def emit_status(self, session_id: str, event_type: str, data: dict):
        payload = {
            "type": event_type,
            **data
        }
        await self.redis.publish(f"session:{session_id}:events", json.dumps(payload))
