import json
import redis.asyncio as aioredis
from typing import List, Optional
from backend.config import settings
from backend.agents.base_agent import AgentTurn

class SharedContext:
    def __init__(self):
        self.redis = aioredis.from_url(settings.redis_url, decode_responses=True)

    async def get(self, session_id: str) -> dict:
        data = await self.redis.get(f"session:{session_id}")
        if data:
            return json.loads(data)
        return {
            "session_id": session_id,
            "book_title": "",
            "book_slug": "",
            "topic": "",
            "segment": 1,
            "turns": [],
            "heat_level": 0.0,
            "interrupt_queue": [],
            "silence_counts": {},
            "current_speaker": None,
            "status": "idle",
            "turn_count": 0
        }

    async def set(self, session_id: str, data: dict):
        await self.redis.set(
            f"session:{session_id}",
            json.dumps(data),
            ex=settings.redis_conversation_ttl
        )

    async def update_turn(self, session_id: str, turn: AgentTurn):
        data = await self.get(session_id)

        for agent_id in data.get("silence_counts", {}).keys():
            if agent_id != turn.speaker and turn.speaker != "host":
                data["silence_counts"][agent_id] = data["silence_counts"].get(agent_id, 0) + 1
            else:
                data["silence_counts"][turn.speaker] = 0

        data["turns"].append({
            "speaker": turn.speaker,
            "text": turn.text,
            "rag_passages": turn.rag_passages,
            "urgency_score": turn.urgency_score,
            "timestamp": turn.timestamp,
            "color_hex": turn.color_hex
        })

        if len(data["turns"]) > 20:
            data["turns"] = data["turns"][-20:]

        data["turn_count"] = data.get("turn_count", 0) + 1
        data["current_speaker"] = turn.speaker

        await self.set(session_id, data)
        await self.update_heat(session_id)

    async def update_heat(self, session_id: str):
        data = await self.get(session_id)
        recent_turns = data.get("turns", [])[-4:]
        if not recent_turns:
            return

        scores = [t.get("urgency_score", 0) for t in recent_turns if t.get("speaker") != "host"]
        current_heat = data.get("heat_level", 0.0)
        if scores:
            data["heat_level"] = sum(scores) / len(scores)
        else:
            data["heat_level"] = max(0.0, current_heat - 0.1)

        await self.set(session_id, data)

    async def get_recent_turns(self, session_id: str, n=6) -> List[AgentTurn]:
        data = await self.get(session_id)
        turns_data = data["turns"][-n:]
        return [AgentTurn(**t) for t in turns_data]
