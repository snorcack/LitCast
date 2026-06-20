#!/bin/bash
mkdir -p backend/agents/personas backend/crew backend/llm/providers backend/tts/providers backend/rag backend/memory backend/output backend/api/routes backend/tests/fixtures scripts books chroma_db episodes frontend/tests frontend/src/types frontend/src/hooks frontend/src/components

touch books/.gitkeep
echo -e "chroma_db/\nepisodes/\n.env\n__pycache__/\n*.pyc\n.pytest_cache/\n.coverage" > .gitignore

cat << 'INNER_EOF' > requirements.txt
fastapi>=0.111
uvicorn[standard]>=0.29
websockets>=12
crewai>=0.51
chromadb>=0.5
pdfplumber>=0.11
ebooklib>=0.18
redis>=5.0
httpx>=0.27
pydantic>=2.7
pydantic-settings>=2.3
python-dotenv>=1.0
langchain-text-splitters>=0.2
openai>=1.30
anthropic>=0.28
elevenlabs>=1.2
google-cloud-texttospeech>=2.16
azure-cognitiveservices-speech>=1.38
pydub>=0.25
pytest>=8.2
pytest-asyncio>=0.23
pytest-cov>=5.0
httpx[test]>=0.27
beautifulsoup4
INNER_EOF

cat << 'INNER_EOF' > backend/config.py
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional

class Settings(BaseSettings):
    llm_provider: str = "none"
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "llama3.2"
    lmstudio_base_url: str = "http://localhost:1234/v1"
    lmstudio_model: str = "mistral-7b-instruct"
    anthropic_api_key: Optional[str] = None
    anthropic_model: str = "claude-sonnet-4-6"
    openai_api_key: Optional[str] = None
    openai_model: str = "gpt-4o"

    tts_provider: str = "none"
    elevenlabs_api_key: Optional[str] = None
    elevenlabs_model: str = "eleven_multilingual_v2"
    openai_tts_voice_default: str = "nova"
    openai_tts_model: str = "tts-1-hd"
    google_application_credentials: Optional[str] = None
    google_tts_language_code: str = "en-US"
    azure_tts_key: Optional[str] = None
    azure_tts_region: Optional[str] = None

    embedding_provider: str = "openai"
    embedding_model: str = "text-embedding-3-small"
    chroma_persist_dir: str = "./chroma_db"
    rag_top_k: int = 5
    rag_chunk_size: int = 512
    rag_chunk_overlap: int = 64

    redis_url: str = "redis://localhost:6379"
    redis_conversation_ttl: int = 7200

    backend_host: str = "0.0.0.0"
    backend_port: int = 8000
    log_level: str = "INFO"

    max_turn_tokens: int = 300
    interrupt_cooldown_seconds: int = 4
    heat_intervention_threshold: float = 0.75
    max_silence_turns: int = 3
    segment_duration_turns: int = 8

    vite_backend_ws_url: str = "ws://localhost:8000/ws"
    vite_backend_api_url: str = "http://localhost:8000"
    vite_enable_test_panel: bool = True

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

settings = Settings()
INNER_EOF

cat << 'INNER_EOF' > backend/main.py
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
INNER_EOF

cat << 'INNER_EOF' > backend/llm/base_provider.py
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import AsyncIterator

@dataclass
class LLMMessage:
    role: str   # "system" | "user" | "assistant"
    content: str

class LLMProviderError(Exception):
    pass

class LLMProvider(ABC):
    max_retries: int = 3
    timeout_seconds: float = 30.0

    @abstractmethod
    async def complete(self, messages: list[LLMMessage], max_tokens: int = 300) -> str:
        pass

    @abstractmethod
    async def stream(self, messages: list[LLMMessage], max_tokens: int = 300) -> AsyncIterator[str]:
        pass

    @property
    @abstractmethod
    def provider_name(self) -> str:
        pass
INNER_EOF

cat << 'INNER_EOF' > backend/llm/providers/none_provider.py
from typing import AsyncIterator
from backend.llm.base_provider import LLMProvider, LLMMessage

class NoneProvider(LLMProvider):
    @property
    def provider_name(self) -> str:
        return "none"

    async def complete(self, messages: list[LLMMessage], max_tokens: int = 300) -> str:
        return "Stub response."

    async def stream(self, messages: list[LLMMessage], max_tokens: int = 300) -> AsyncIterator[str]:
        yield "Stub response."
INNER_EOF

cat << 'INNER_EOF' > backend/llm/llm_router.py
import functools
from backend.config import settings
from backend.llm.base_provider import LLMProvider
from backend.llm.providers.none_provider import NoneProvider

@functools.lru_cache()
def get_llm_provider() -> LLMProvider:
    return NoneProvider()
INNER_EOF

cat << 'INNER_EOF' > backend/tts/base_provider.py
from abc import ABC, abstractmethod

class TTSProvider(ABC):
    audio_format: str = "mp3"

    @abstractmethod
    async def synthesize(self, text: str, voice_id: str) -> bytes:
        pass

    @abstractmethod
    def get_voice_id(self, persona_name: str) -> str:
        pass

    @property
    @abstractmethod
    def provider_name(self) -> str:
        pass
INNER_EOF

cat << 'INNER_EOF' > backend/tts/providers/none_provider.py
from backend.tts.base_provider import TTSProvider

class NoneProvider(TTSProvider):
    @property
    def provider_name(self) -> str:
        return "none"

    async def synthesize(self, text: str, voice_id: str) -> bytes:
        return b""

    def get_voice_id(self, persona_name: str) -> str:
        return "none"
INNER_EOF

cat << 'INNER_EOF' > backend/tts/tts_router.py
import functools
from backend.config import settings
from backend.tts.base_provider import TTSProvider
from backend.tts.providers.none_provider import NoneProvider

@functools.lru_cache()
def get_tts_provider() -> TTSProvider:
    return NoneProvider()
INNER_EOF

cat << 'INNER_EOF' > backend/rag/retriever.py
from backend.config import settings

class BookRetriever:
    def __init__(self):
        pass

    def query(self, book_slug: str, topic: str, persona_bias_prefix: str, agent_question: str, top_k: int = None) -> list[dict]:
        return []

    def list_books(self) -> list[dict]:
        return []
INNER_EOF

cat << 'INNER_EOF' > backend/agents/personas/architect.yaml
name: "The Architect"
short_id: architect
lens: "Structural design, spatial logic, built environments, engineering systems"
quirks:
  - "Speaks in blueprints — always asks 'what holds this up?'"
  - "Gets visibly agitated when worldbuilding physics are inconsistent"
  - "Tends to over-explain load-bearing metaphors before reaching the point"
  - "Rarely uses character names — refers to people by their function"
interrupt_threshold: 0.65
disagreement_style: "calm, persistent, uses rhetorical questions"
rag_bias_prefix: "From a structural design and architectural perspective:"
system_prompt_addendum: |
  You are a professional architect participating in a book podcast. You analyse
  literature through the lens of built environments, spatial logic, and structural
  integrity. You back every argument with specific passages from the book.
  Keep responses under 120 words. Always cite the passage you're referencing.
voice_env_key: VOICE_ARCHITECT
color_hex: "#D85A30"
INNER_EOF

cat << 'INNER_EOF' > backend/agents/personas/scientist.yaml
name: "The Scientist"
short_id: scientist
lens: "Factual accuracy, plausibility, scientific method skepticism, empiricism"
quirks:
  - "Treats magic systems like poorly documented physics"
  - "Constantly tries to calculate the caloric requirements of fictional creatures"
  - "Uses 'hypothesis' and 'evidence' in casual conversation"
  - "Gets distracted by inaccurate descriptions of orbital mechanics"
interrupt_threshold: 0.70
disagreement_style: "methodical, cites real-world laws of nature, slightly pedantic"
rag_bias_prefix: "From a scientific and empirical standpoint:"
system_prompt_addendum: |
  You are a rigorous scientist on a book podcast. You evaluate fiction based on
  plausibility and internal consistency, treating the text as data.
  Keep responses under 120 words. Always cite the passage you're referencing.
voice_env_key: VOICE_SCIENTIST
color_hex: "#3498DB"
INNER_EOF

cat << 'INNER_EOF' > backend/agents/base_agent.py
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
INNER_EOF

cat << 'INNER_EOF' > backend/memory/shared_context.py
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
INNER_EOF

cat << 'INNER_EOF' > backend/agents/guest_agent.py
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
INNER_EOF

cat << 'INNER_EOF' > backend/agents/host_agent.py
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
INNER_EOF

cat << 'INNER_EOF' > backend/output/transcript_streamer.py
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
INNER_EOF

cat << 'INNER_EOF' > backend/output/episode_packager.py
import json
from pathlib import Path

class EpisodePackager:
    def __init__(self):
        self.audio_chunks = []
        self.markers = []

    def add_audio_chunk(self, speaker: str, audio_bytes: bytes, turn_index: int = None):
        if audio_bytes:
            self.audio_chunks.append({"speaker": speaker, "audio": audio_bytes})

    def add_marker(self, turn_index: int, timestamp: float, summary: str):
        self.markers.append({"turn": turn_index, "timestamp": timestamp, "summary": summary})

    def finalize(self, session_id: str, context_data: dict = None):
        output_dir = Path("episodes")
        output_dir.mkdir(exist_ok=True)
        # Mock packaging logic to avoid depending on pydub / ffmpeg for now
INNER_EOF

cat << 'INNER_EOF' > backend/crew/podcast_crew.py
from typing import List
from pathlib import Path
from backend.agents.guest_agent import GuestAgent
from backend.agents.host_agent import HostAgent
from backend.llm.llm_router import get_llm_provider
from backend.tts.tts_router import get_tts_provider
from backend.rag.retriever import BookRetriever

class PodcastCrew:
    def __init__(self, session_id: str, book_title: str, topic: str, persona_ids: List[str]):
        self.session_id = session_id
        self.book_title = book_title
        self.topic = topic
        self.persona_ids = persona_ids

        self.llm_provider = get_llm_provider()
        self.tts_provider = get_tts_provider()
        self.retriever = BookRetriever()

        self.host_backend = HostAgent(Path("backend/agents/personas/architect.yaml"), self.llm_provider, self.tts_provider, self.retriever)
        self.guests_backend = []
        for pid in persona_ids:
            path = Path(f"backend/agents/personas/{pid}.yaml")
            self.guests_backend.append(GuestAgent(path, self.llm_provider, self.tts_provider, self.retriever))
INNER_EOF

cat << 'INNER_EOF' > backend/crew/conversation_engine.py
import asyncio
from backend.crew.podcast_crew import PodcastCrew
from backend.memory.shared_context import SharedContext
from backend.output.transcript_streamer import TranscriptStreamer
from backend.output.episode_packager import EpisodePackager
from backend.config import settings

class ConversationEngine:
    def __init__(self, session_id: str, crew: PodcastCrew, context: SharedContext):
        self.session_id = session_id
        self.crew = crew
        self.context = context
        self.status = "running"
        self.transcript_streamer = TranscriptStreamer()
        self.episode_packager = EpisodePackager()

    async def run(self):
        ctx_data = await self.context.get(self.session_id)
        ctx_data["status"] = "running"
        await self.context.set(self.session_id, ctx_data)

        while self.status == "running":
            ctx_data = await self.context.get(self.session_id)
            if ctx_data.get("status") != "running":
                self.status = ctx_data.get("status", "idle")
                break

            scores_tasks = [guest.score_interrupt(self.context, self.session_id) for guest in self.crew.guests_backend]
            scores = await asyncio.gather(*scores_tasks)

            queue_items = []
            for i, guest in enumerate(self.crew.guests_backend):
                if scores[i] >= guest.persona.interrupt_threshold:
                    queue_items.append((guest.short_id, scores[i]))

            queue_items.sort(key=lambda x: x[1], reverse=True)
            interrupt_queue = [x[0] for x in queue_items]

            next_speaker_id = await self.crew.host_backend.evaluate_queue(self.context, self.session_id, interrupt_queue)

            if next_speaker_id is None:
                turn = await self.crew.host_backend.generate_moderation(self.context, self.session_id, "heat or silence")
                speaker_agent = self.crew.host_backend
            else:
                guest = next((g for g in self.crew.guests_backend if g.short_id == next_speaker_id), None)
                if not guest:
                    turn = await self.crew.host_backend.generate_moderation(self.context, self.session_id, "fallback")
                    speaker_agent = self.crew.host_backend
                else:
                    turn = await guest.generate_response(self.context, self.session_id)
                    speaker_agent = guest

            audio = await speaker_agent.speak(turn.text)
            await self.context.update_turn(self.session_id, turn)

            try:
                await self.transcript_streamer.emit(turn, audio, self.session_id)
            except Exception:
                pass

            ctx_data = await self.context.get(self.session_id)
            if ctx_data.get("turn_count", 0) % settings.segment_duration_turns == 0:
                summary = await self.crew.host_backend.generate_summary(self.context, self.session_id)
                await self.context.update_turn(self.session_id, summary)

            await asyncio.sleep(settings.interrupt_cooldown_seconds)

    async def pause(self):
        self.status = "paused"
        ctx = await self.context.get(self.session_id)
        ctx["status"] = "paused"
        await self.context.set(self.session_id, ctx)

    async def resume(self):
        self.status = "running"
        ctx = await self.context.get(self.session_id)
        ctx["status"] = "running"
        await self.context.set(self.session_id, ctx)

    async def stop(self):
        self.status = "complete"
        ctx = await self.context.get(self.session_id)
        ctx["status"] = "complete"
        await self.context.set(self.session_id, ctx)
        self.episode_packager.finalize(self.session_id)
INNER_EOF

cat << 'INNER_EOF' > backend/api/websocket.py
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import redis.asyncio as aioredis
import asyncio
from backend.config import settings

router = APIRouter(tags=["ws"])

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, session_id: str):
    await websocket.accept()

    redis = aioredis.from_url(settings.redis_url, decode_responses=True)
    pubsub = redis.pubsub()
    await pubsub.subscribe(f"session:{session_id}:events")

    try:
        while True:
            message = await pubsub.get_message(ignore_subscribe_messages=True, timeout=0.1)
            if message:
                await websocket.send_text(message["data"])

            try:
                data = await asyncio.wait_for(websocket.receive_text(), timeout=0.1)
                if data == "ping":
                    await websocket.send_text('{"type": "pong"}')
            except asyncio.TimeoutError:
                pass
    except WebSocketDisconnect:
        pass
    except Exception as e:
        pass
    finally:
        await pubsub.unsubscribe()
        await redis.aclose()
INNER_EOF

cat << 'INNER_EOF' > backend/api/routes/stream.py
from fastapi import APIRouter, Request
from fastapi.responses import StreamingResponse
import redis.asyncio as aioredis
import asyncio
from backend.config import settings

router = APIRouter(prefix="/stream", tags=["stream"])

async def event_generator(session_id: str, request: Request):
    redis = aioredis.from_url(settings.redis_url, decode_responses=True)
    pubsub = redis.pubsub()
    await pubsub.subscribe(f"session:{session_id}:events")

    try:
        while True:
            if await request.is_disconnected():
                break

            message = await pubsub.get_message(ignore_subscribe_messages=True, timeout=0.1)
            if message:
                yield f"data: {message['data']}\n\n"
            else:
                yield ": keepalive\n\n"
                break

    finally:
        await pubsub.unsubscribe()
        await redis.aclose()

@router.get("")
async def sse_stream(session_id: str, request: Request):
    return StreamingResponse(event_generator(session_id, request), media_type="text/event-stream")
INNER_EOF

cat << 'INNER_EOF' > backend/api/routes/episode.py
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
INNER_EOF

# Ensure __init__.py files
touch backend/__init__.py backend/llm/__init__.py backend/llm/providers/__init__.py backend/tts/__init__.py backend/tts/providers/__init__.py backend/rag/__init__.py backend/memory/__init__.py backend/agents/__init__.py backend/crew/__init__.py backend/output/__init__.py backend/api/__init__.py backend/api/routes/__init__.py backend/tests/__init__.py
