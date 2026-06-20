# ARCHITECTURE.md — LitCast Virtual Book Podcast System

## Overview

LitCast is a multi-agent AI podcast system where 4–5 persona-driven guest agents debate books in a free-for-all format, moderated by a host agent. Agents retrieve evidence from a pre-indexed RAG library, generate speech via a swappable LLM backend, and produce audio via a swappable cloud TTS service. A React radio dashboard streams the live transcript, agent status, and playback.

---

## Repository Layout

```
litcast/
├── .env.example                   # All environment variables (copy → .env)
├── .env                           # Local secrets (gitignored)
├── scripts/
│   ├── run_dev.bat                # Windows: start all services
│   ├── run_dev.sh                 # Unix: start all services
│   ├── run_ingest.bat             # Windows: index books into vector store
│   ├── run_ingest.sh              # Unix: index books
│   ├── run_tests.bat              # Windows: run full test suite
│   ├── run_tests.sh               # Unix: run full test suite
│   └── setup_env.bat / .sh        # First-time environment setup
├── backend/
│   ├── main.py                    # FastAPI entrypoint
│   ├── config.py                  # Loads .env, exposes typed Settings object
│   ├── agents/
│   │   ├── base_agent.py          # AgentBase: RAG + LLM + persona interface
│   │   ├── host_agent.py          # HostAgent: moderation, turn management
│   │   ├── guest_agent.py         # GuestAgent: persona loop, interrupt scoring
│   │   └── personas/              # YAML persona definitions (one per guest)
│   │       ├── architect.yaml
│   │       ├── feminist_critic.yaml
│   │       ├── scientist.yaml
│   │       ├── historian.yaml
│   │       └── pop_culture_fan.yaml
│   ├── crew/
│   │   ├── podcast_crew.py        # CrewAI setup: hierarchical process, agent wiring
│   │   └── conversation_engine.py # Free-for-all loop, interrupt queue, heat tracker
│   ├── llm/
│   │   ├── llm_router.py          # Selects local or cloud LLM from config
│   │   ├── providers/
│   │   │   ├── ollama_provider.py # Ollama local LLM (llama3, mistral, etc.)
│   │   │   ├── lmstudio_provider.py # LM Studio local server
│   │   │   ├── anthropic_provider.py
│   │   │   └── openai_provider.py
│   │   └── base_provider.py       # Abstract LLMProvider interface
│   ├── tts/
│   │   ├── tts_router.py          # Selects TTS provider from config
│   │   ├── providers/
│   │   │   ├── elevenlabs_provider.py
│   │   │   ├── openai_tts_provider.py  # OpenAI TTS (tts-1 / tts-1-hd)
│   │   │   ├── google_tts_provider.py  # Google Cloud TTS
│   │   │   └── azure_tts_provider.py   # Azure Cognitive Services TTS
│   │   └── base_provider.py       # Abstract TTSProvider interface
│   ├── rag/
│   │   ├── ingest.py              # Book ingestion pipeline (PDF/EPUB/TXT → chunks → embeddings)
│   │   ├── retriever.py           # Persona-biased vector search
│   │   └── embeddings.py          # Embedding provider (OpenAI / local nomic-embed)
│   ├── memory/
│   │   └── shared_context.py      # Redis-backed shared conversation state
│   ├── output/
│   │   ├── transcript_streamer.py # SSE / WebSocket transcript pusher
│   │   └── episode_packager.py    # Bundles MP3 + transcript JSON
│   ├── api/
│   │   ├── routes/
│   │   │   ├── session.py         # POST /session/start, POST /session/stop
│   │   │   ├── stream.py          # GET /stream (SSE transcript)
│   │   │   ├── episode.py         # GET /episode/{id} download
│   │   │   └── library.py         # GET /library (indexed books list)
│   │   └── websocket.py           # WS /ws (real-time agent events)
│   └── tests/
│       ├── conftest.py
│       ├── test_llm_providers.py
│       ├── test_tts_providers.py
│       ├── test_rag_retrieval.py
│       ├── test_agent_persona.py
│       ├── test_host_moderation.py
│       ├── test_interrupt_scoring.py
│       ├── test_conversation_engine.py
│       ├── test_api_routes.py
│       └── fixtures/
│           ├── sample_book.txt    # Short public-domain excerpt for RAG tests
│           └── mock_personas.yaml
├── frontend/
│   ├── package.json
│   ├── vite.config.ts
│   ├── src/
│   │   ├── App.tsx
│   │   ├── components/
│   │   │   ├── RadioDashboard.tsx    # Main layout shell
│   │   │   ├── TranscriptPanel.tsx   # Scrolling colour-coded transcript
│   │   │   ├── GuestStatusRow.tsx    # 5 persona cards (speaking/thinking/idle)
│   │   │   ├── TopicSidebar.tsx      # Book title, episode topic, segment list
│   │   │   ├── WaveformStrip.tsx     # Web Audio API visualiser
│   │   │   ├── HeatMeter.tsx         # Conversation tension indicator
│   │   │   ├── EpisodeControls.tsx   # Pause/skip/export controls
│   │   │   └── TestPanel.tsx         # Dev-only test harness UI (topic injector)
│   │   ├── hooks/
│   │   │   ├── useWebSocket.ts
│   │   │   ├── useTranscript.ts
│   │   │   └── useAudioPlayer.ts
│   │   └── types/
│   │       └── podcast.ts            # Shared TypeScript types
│   └── tests/
│       ├── RadioDashboard.test.tsx
│       ├── TranscriptPanel.test.tsx
│       └── TestPanel.test.tsx
├── books/                          # Drop raw books here for ingest
│   └── .gitkeep
├── chroma_db/                      # ChromaDB persistent storage (gitignored)
├── episodes/                       # Output MP3 + JSON episodes (gitignored)
└── requirements.txt
```

---

## Environment Variables (.env.example)

```dotenv
# ─── LLM PROVIDER ───────────────────────────────────────────────────────────
# Options: ollama | lmstudio | anthropic | openai
LLM_PROVIDER=ollama

# Ollama (local)
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3.2

# LM Studio (local)
LMSTUDIO_BASE_URL=http://localhost:1234/v1
LMSTUDIO_MODEL=mistral-7b-instruct

# Anthropic (cloud)
ANTHROPIC_API_KEY=
ANTHROPIC_MODEL=claude-sonnet-4-6

# OpenAI (cloud)
OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o

# ─── TTS PROVIDER ────────────────────────────────────────────────────────────
# Options: elevenlabs | openai | google | azure | none (transcript-only mode)
TTS_PROVIDER=elevenlabs

# ElevenLabs
ELEVENLABS_API_KEY=
ELEVENLABS_MODEL=eleven_multilingual_v2

# OpenAI TTS
OPENAI_TTS_VOICE_DEFAULT=nova
OPENAI_TTS_MODEL=tts-1-hd

# Google Cloud TTS
GOOGLE_APPLICATION_CREDENTIALS=./google_credentials.json
GOOGLE_TTS_LANGUAGE_CODE=en-US

# Azure TTS
AZURE_TTS_KEY=
AZURE_TTS_REGION=eastus

# ─── VOICE MAP ───────────────────────────────────────────────────────────────
# Per-persona voice IDs (provider-specific). Overrides default.
VOICE_HOST=
VOICE_ARCHITECT=
VOICE_FEMINIST_CRITIC=
VOICE_SCIENTIST=
VOICE_HISTORIAN=
VOICE_POP_CULTURE_FAN=

# ─── RAG / EMBEDDINGS ────────────────────────────────────────────────────────
# Options: openai | nomic (local via ollama)
EMBEDDING_PROVIDER=openai
EMBEDDING_MODEL=text-embedding-3-small
CHROMA_PERSIST_DIR=./chroma_db
RAG_TOP_K=5
RAG_CHUNK_SIZE=512
RAG_CHUNK_OVERLAP=64

# ─── REDIS (shared memory) ───────────────────────────────────────────────────
REDIS_URL=redis://localhost:6379
REDIS_CONVERSATION_TTL=7200

# ─── BACKEND ─────────────────────────────────────────────────────────────────
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8000
LOG_LEVEL=INFO

# ─── CONVERSATION ENGINE ─────────────────────────────────────────────────────
MAX_TURN_TOKENS=300
INTERRUPT_COOLDOWN_SECONDS=4
HEAT_INTERVENTION_THRESHOLD=0.75
MAX_SILENCE_TURNS=3            # guest re-enters if silent this many turns
SEGMENT_DURATION_TURNS=8       # host summarises every N turns

# ─── FRONTEND ────────────────────────────────────────────────────────────────
VITE_BACKEND_WS_URL=ws://localhost:8000/ws
VITE_BACKEND_API_URL=http://localhost:8000
VITE_ENABLE_TEST_PANEL=true    # set false in production
```

---

## LLM Provider Interface

```python
# backend/llm/base_provider.py
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import AsyncIterator

@dataclass
class LLMMessage:
    role: str   # "system" | "user" | "assistant"
    content: str

class LLMProvider(ABC):
    @abstractmethod
    async def complete(self, messages: list[LLMMessage], max_tokens: int = 300) -> str:
        """Single completion, returns full string."""

    @abstractmethod
    async def stream(self, messages: list[LLMMessage], max_tokens: int = 300) -> AsyncIterator[str]:
        """Streaming completion, yields token chunks."""

    @property
    @abstractmethod
    def provider_name(self) -> str: ...
```

The `llm_router.py` reads `LLM_PROVIDER` from config and returns the matching provider. All agents call `provider.complete()` — swapping local↔cloud requires only changing the env var.

---

## TTS Provider Interface

```python
# backend/tts/base_provider.py
from abc import ABC, abstractmethod

class TTSProvider(ABC):
    @abstractmethod
    async def synthesize(self, text: str, voice_id: str) -> bytes:
        """Returns raw MP3/WAV bytes for the given text and voice."""

    @abstractmethod
    def get_voice_id(self, persona_name: str) -> str:
        """Maps a persona name to provider-specific voice ID from env."""

    @property
    @abstractmethod
    def provider_name(self) -> str: ...
```

Setting `TTS_PROVIDER=none` disables audio entirely — the system runs in transcript-only mode, useful for development and testing.

---

## Persona YAML Schema

```yaml
# backend/agents/personas/architect.yaml
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
color_hex: "#D85A30"   # used by frontend for transcript colour coding
```

---

## Conversation Engine — Free-for-All Logic

```
Every conversation tick (triggered after each agent turn):

1. For each guest agent (in parallel):
   a. Read shared context: topic + last 6 turns + heat_level
   b. Run persona-biased RAG query → top-5 passages
   c. Score interrupt urgency:
      urgency = (persona_relevance × 0.50)
              + (disagreement_with_last_turn × 0.30)
              + (silence_penalty × 0.20)
      where silence_penalty = min(turns_silent / MAX_SILENCE_TURNS, 1.0)

2. Build interrupt queue: agents with urgency > interrupt_threshold, sorted desc

3. Host agent evaluates queue:
   - If heat_level > HEAT_INTERVENTION_THRESHOLD → Host speaks (moderates)
   - Else if queue non-empty → grant token to top agent
   - Else → Host prompts a silent agent or advances segment

4. Granted agent generates response (LLM call with persona prompt + RAG context)

5. TTS synthesises audio → streams to frontend

6. Shared context updated: new turn appended, heat_level recalculated
   heat_level = rolling average of (disagreement scores in last 4 turns)

7. Every SEGMENT_DURATION_TURNS turns → Host generates summary, logs chapter marker
```

---

## Shared Context Schema (Redis)

```python
{
  "session_id": str,
  "book_title": str,
  "topic": str,
  "segment": int,                   # current segment number
  "turns": [                        # last N turns (ring buffer, max 20)
    {
      "speaker": str,               # persona short_id or "host"
      "text": str,
      "rag_passages": [str],        # passages used (for debug panel)
      "urgency_score": float,
      "timestamp": float
    }
  ],
  "heat_level": float,              # 0.0–1.0
  "interrupt_queue": [str],         # ordered list of agent short_ids
  "silence_counts": {str: int},     # turns_silent per agent
  "current_speaker": str | None,
  "status": "idle|running|paused|complete"
}
```

---

## RAG Ingest Pipeline

```
books/ (PDF | EPUB | TXT)
  → format_loader (pdfplumber / ebooklib / plain text)
  → chapter_splitter (by heading pattern or fixed-size fallback)
  → sentence_window_chunker (512 tokens, 64 overlap)
  → metadata_tagger: {book, chapter, page, chunk_index}
  → embed (EMBEDDING_PROVIDER)
  → upsert to ChromaDB collection named "{book_slug}"
```

At query time:
```python
query = f"{persona.rag_bias_prefix} Regarding '{topic}' in {book_title}: {agent_question}"
results = chroma.query(query_texts=[query], n_results=RAG_TOP_K, where={"book": book_slug})
```

---

## API Routes

| Method | Path | Description |
|--------|------|-------------|
| POST | `/session/start` | `{book_title, topic, personas[]}` → starts crew, returns session_id |
| POST | `/session/stop` | Stops current session |
| POST | `/session/pause` | Pause / resume |
| GET | `/stream` | SSE stream of transcript events |
| WS | `/ws` | WebSocket: agent events, audio chunks, heat updates |
| GET | `/library` | Lists all indexed books |
| POST | `/library/ingest` | Triggers ingest for a book in `books/` |
| GET | `/episode/{id}` | Download packaged episode (MP3 + JSON) |
| GET | `/test/ping_llm` | Test panel: verify LLM provider connection |
| GET | `/test/ping_tts` | Test panel: verify TTS provider, returns sample audio |
| POST | `/test/single_agent` | Test panel: run one agent turn on a topic, returns text |
| POST | `/test/rag_query` | Test panel: run a RAG query, returns top-k passages |
| GET | `/test/providers` | Test panel: lists active LLM + TTS providers and models |

---

## Test Structure

### Backend (pytest)

| File | What it tests |
|------|---------------|
| `test_llm_providers.py` | Each provider: completion returns string, streaming yields chunks, handles errors gracefully |
| `test_tts_providers.py` | Each provider: synthesize returns bytes > 0, voice mapping from env, graceful no-key handling |
| `test_rag_retrieval.py` | Ingest sample book, query returns top-k with correct metadata, persona bias shifts results |
| `test_agent_persona.py` | Persona YAML loads correctly, rag_bias_prefix injected, quirks appear in output style |
| `test_host_moderation.py` | Host intervenes above heat threshold, host grants token to correct queue head |
| `test_interrupt_scoring.py` | Urgency formula correctness, silence penalty accumulates, cooldown respected |
| `test_conversation_engine.py` | Full 8-turn simulated session (mocked LLM), shared context state correct at each step |
| `test_api_routes.py` | All routes return correct status codes, session lifecycle, SSE emits events |

### Frontend (Vitest + React Testing Library)

| File | What it tests |
|------|---------------|
| `RadioDashboard.test.tsx` | Renders without crash, layout elements present |
| `TranscriptPanel.test.tsx` | Colours per persona, auto-scroll on new turn |
| `TestPanel.test.tsx` | Topic injection triggers WS message, provider status displayed |

---

## Run Scripts

### `scripts/setup_env.sh` / `.bat`
```bash
# Creates virtualenv, installs requirements, copies .env.example → .env,
# starts Redis via Docker if not running, runs initial ChromaDB directory setup.
```

### `scripts/run_dev.sh` / `.bat`
```bash
# Starts: Redis (docker), FastAPI backend (uvicorn), React frontend (vite dev)
# All in parallel with colour-coded terminal output via concurrently / foreman.
```

### `scripts/run_ingest.sh` / `.bat`
```bash
# Args: [--book path/to/book.pdf] [--all] (indexes all files in books/)
# Prints: chunk count, embedding count, collection name on completion.
```

### `scripts/run_tests.sh` / `.bat`
```bash
# pytest backend/tests/ -v --tb=short
# vitest run frontend/tests/
# Generates coverage report to coverage/
```

---

## Frontend Test Panel (dev only)

Enabled when `VITE_ENABLE_TEST_PANEL=true`. A collapsible drawer at the bottom of the radio dashboard with:

- **Provider status** — green/red badges for LLM and TTS, model names, latency ping
- **Topic injector** — text field + book selector → POST `/session/start`
- **Single agent tester** — pick persona + enter topic → runs one turn, shows text output + RAG passages used
- **RAG explorer** — enter any query, pick book → returns top-5 passages with similarity scores
- **Voice sampler** — per-persona "play sample" buttons → calls `/test/ping_tts` for each voice
- **Heat override** — slider to manually set heat_level in Redis → test host moderation triggers
- **Session log** — raw JSON view of current shared context state

---

## Provider Swap Reference

To switch LLM: change `LLM_PROVIDER` in `.env`. No code changes.

| LLM_PROVIDER | Requires | Notes |
|---|---|---|
| `ollama` | Ollama running locally | `ollama pull llama3.2` first |
| `lmstudio` | LM Studio server on | Enable local server in LM Studio UI |
| `anthropic` | `ANTHROPIC_API_KEY` | Recommended for quality |
| `openai` | `OPENAI_API_KEY` | GPT-4o or GPT-4o-mini |

To switch TTS: change `TTS_PROVIDER` in `.env`. Voice IDs must be set in `VOICE_*` env vars for the chosen provider.

| TTS_PROVIDER | Requires | Quality | Cost |
|---|---|---|---|
| `elevenlabs` | `ELEVENLABS_API_KEY` | Best | $$$ |
| `openai` | `OPENAI_API_KEY` | Excellent | $$ |
| `google` | `GOOGLE_APPLICATION_CREDENTIALS` | Good | $ |
| `azure` | `AZURE_TTS_KEY` + `AZURE_TTS_REGION` | Good | $ |
| `none` | — | No audio, transcript only | Free |

---

## Data Flow Summary

```
User (frontend)
  → POST /session/start {book, topic}
      → PodcastCrew initialized (CrewAI hierarchical)
      → SharedContext seeded in Redis
      → ConversationEngine starts tick loop

Each tick:
  → All GuestAgents score interrupt urgency (parallel)
  → HostAgent grants token to winner (or intervenes)
  → Winning agent: RAG query → LLM generation → response text
  → TTSRouter.synthesize(text, voice_id) → audio bytes
  → TranscriptStreamer pushes {speaker, text, audio_b64} via WebSocket
  → Frontend: appends transcript line, plays audio, updates guest status

Every SEGMENT_DURATION_TURNS:
  → HostAgent generates summary turn
  → EpisodePackager appends chapter marker

POST /session/stop:
  → EpisodePackager.finalize() → writes episodes/{id}.mp3 + .json
  → Redis session cleared
```
