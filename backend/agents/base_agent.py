import yaml
import os
from pathlib import Path
from dataclasses import dataclass
from typing import List
from backend.llm.base_provider import LLMProvider, LLMMessage
from backend.tts.base_provider import TTSProvider
from backend.rag.retriever import BookRetriever

@dataclass
class PersonaConfig:
    name: str
    short_id: str
    lens: str
    quirks: List[str]
    interrupt_threshold: float
    disagreement_style: str
    rag_bias_prefix: str
    system_prompt_addendum: str
    voice_env_key: str
    color_hex: str

@dataclass
class AgentTurn:
    speaker: str
    text: str
    rag_passages: List[str]
    urgency_score: float
    timestamp: float = 0.0
    color_hex: str = "#FFFFFF"

class AgentBase:
    def __init__(self, persona_path: Path, llm: LLMProvider, tts: TTSProvider, retriever: BookRetriever):
        self.llm = llm
        self.tts = tts
        self.retriever = retriever
        self.persona = self.load_persona(persona_path)

    @property
    def short_id(self) -> str:
        return self.persona.short_id

    def load_persona(self, path: Path) -> PersonaConfig:
        with open(path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        return PersonaConfig(**data)

    def build_system_prompt(self, topic: str, book_title: str) -> str:
        prompt = f"You are {self.persona.name}. You analyze '{book_title}' focusing on '{topic}'.\n"
        prompt += f"Your lens: {self.persona.lens}\n"
        prompt += "Your quirks:\n" + "\n".join([f"- {q}" for q in self.persona.quirks]) + "\n"
        prompt += f"When disagreeing, be {self.persona.disagreement_style}.\n"
        prompt += f"\n{self.persona.system_prompt_addendum}"
        return prompt

    def retrieve_context(self, topic: str, question: str, book_slug: str) -> list[dict]:
        return self.retriever.query(
            book_slug=book_slug,
            topic=topic,
            persona_bias_prefix=self.persona.rag_bias_prefix,
            agent_question=question
        )

    def format_rag_context(self, passages: list[dict]) -> str:
        if not passages:
            return "No passages found."
        formatted = []
        for p in passages:
            formatted.append(f"[Chapter {p.get('chapter', '?')}, Chunk {p.get('chunk_index', '?')}]: {p.get('text', '')}")
        return "\n\n".join(formatted)

    async def generate(self, messages: list[LLMMessage], max_tokens: int = 300) -> str:
        return await self.llm.complete(messages, max_tokens=max_tokens)

    async def speak(self, text: str) -> bytes:
        return await self.tts.synthesize(text, self.voice_id)

    @property
    def voice_id(self) -> str:
        val = os.getenv(self.persona.voice_env_key)
        if val:
            return val
        return self.tts.get_voice_id(self.persona.short_id)
