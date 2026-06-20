import time
from typing import List
from backend.agents.base_agent import AgentBase, AgentTurn
from backend.memory.shared_context import SharedContext
from backend.config import settings

class GuestAgent(AgentBase):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.last_spoke_at = 0.0

    async def score_interrupt(self, context: SharedContext, session_id: str) -> float:
        now = time.time()
        if now - self.last_spoke_at < settings.interrupt_cooldown_seconds:
            return 0.0

        ctx_data = await context.get(session_id)
        recent_turns = ctx_data.get("turns", [])
        if not recent_turns:
            return 0.1

        last_turn = recent_turns[-1]
        if last_turn["speaker"] == self.short_id:
            return 0.0

        silence_counts = ctx_data.get("silence_counts", {})
        my_silence = silence_counts.get(self.short_id, 0)

        lens_keywords = [w.lower() for w in self.persona.lens.split() if len(w) > 3]
        last_text_lower = last_turn["text"].lower()
        overlap_count = sum(1 for kw in lens_keywords if kw in last_text_lower)
        persona_relevance = min(overlap_count * 0.2, 1.0)

        disagreement = 0.5
        silence_penalty = min(my_silence / settings.max_silence_turns, 1.0)

        score = (persona_relevance * 0.5) + (disagreement * 0.3) + (silence_penalty * 0.2)
        return score

    async def generate_response(self, context: SharedContext, session_id: str) -> AgentTurn:
        ctx_data = await context.get(session_id)
        topic = ctx_data.get("topic", "")
        book_slug = ctx_data.get("book_slug", "")
        book_title = ctx_data.get("book_title", "")

        recent_turns = await context.get_recent_turns(session_id, n=4)
        last_text = recent_turns[-1].text if recent_turns else "Let's start."

        passages = self.retrieve_context(topic, last_text, book_slug)
        rag_text = self.format_rag_context(passages)

        system_prompt = self.build_system_prompt(topic, book_title)
        context_str = "\n".join([f"{t.speaker}: {t.text}" for t in recent_turns])

        from backend.llm.base_provider import LLMMessage
        messages = [
            LLMMessage(role="system", content=system_prompt),
            LLMMessage(role="user", content=f"Recent conversation:\n{context_str}\n\nRelevant passages:\n{rag_text}\n\nYour response:")
        ]

        response_text = await self.generate(messages, max_tokens=settings.max_turn_tokens)
        self.last_spoke_at = time.time()

        return AgentTurn(
            speaker=self.short_id,
            text=response_text,
            rag_passages=[p.get("text") for p in passages],
            urgency_score=1.0,
            timestamp=self.last_spoke_at,
            color_hex=self.persona.color_hex
        )
