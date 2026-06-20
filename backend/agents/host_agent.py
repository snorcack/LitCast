import time
from typing import List, Optional
from backend.agents.base_agent import AgentBase, AgentTurn
from backend.memory.shared_context import SharedContext
from backend.config import settings

class HostAgent(AgentBase):
    async def evaluate_queue(self, context: SharedContext, session_id: str, interrupt_queue: List[str]) -> Optional[str]:
        ctx_data = await context.get(session_id)
        heat_level = ctx_data.get("heat_level", 0.0)

        if heat_level > settings.heat_intervention_threshold:
            return None

        silence_counts = ctx_data.get("silence_counts", {})
        if silence_counts and all(v >= settings.max_silence_turns for v in silence_counts.values()):
            return None

        if interrupt_queue:
            return interrupt_queue[0]

        return None

    async def generate_moderation(self, context: SharedContext, session_id: str, reason: str) -> AgentTurn:
        ctx_data = await context.get(session_id)
        topic = ctx_data.get("topic", "")
        book_title = ctx_data.get("book_title", "")

        system_prompt = f"You are the Host. Reason: {reason}."

        from backend.llm.base_provider import LLMMessage
        messages = [
            LLMMessage(role="system", content=system_prompt),
            LLMMessage(role="user", content=f"Your moderation response:")
        ]

        response_text = await self.generate(messages, max_tokens=settings.max_turn_tokens)

        return AgentTurn(
            speaker="host",
            text=response_text,
            rag_passages=[],
            urgency_score=1.0,
            timestamp=time.time(),
            color_hex="#FFFFFF"
        )

    async def generate_summary(self, context: SharedContext, session_id: str) -> AgentTurn:
        ctx_data = await context.get(session_id)
        segment = ctx_data.get("segment", 1)

        from backend.llm.base_provider import LLMMessage
        messages = [
            LLMMessage(role="system", content="You are the Host."),
            LLMMessage(role="user", content=f"Summarize:")
        ]

        response_text = await self.generate(messages, max_tokens=settings.max_turn_tokens)

        ctx_data["segment"] = segment + 1
        await context.set(session_id, ctx_data)

        return AgentTurn(
            speaker="host",
            text=response_text,
            rag_passages=[],
            urgency_score=1.0,
            timestamp=time.time(),
            color_hex="#FFFFFF"
        )
