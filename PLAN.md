# PLAN.md — LitCast Build Plan
# Agentic execution guide for Claude Code / Cursor / Jules
# Each phase is independently executable. Complete phases in order.
# Run `scripts/run_tests.bat` after each phase to verify before continuing.

---

## Phase 0 — Project Scaffold & Environment

### Goal
Repository structure, dependency files, environment config, and run scripts in place. Developer can clone and set up in one command.

### Tasks

**0.1 — Create directory tree**
Create all directories and empty placeholder files matching the layout in ARCHITECTURE.md §Repository Layout. Add `.gitkeep` in `books/`. Add `chroma_db/` and `episodes/` to `.gitignore`.

**0.2 — requirements.txt**
```
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
```

**0.3 — .env.example**
Write the full `.env.example` from ARCHITECTURE.md §Environment Variables verbatim.

**0.4 — backend/config.py**
Implement a `Settings` class using `pydantic-settings` `BaseSettings`. Load all env vars with typed fields, defaults, and docstrings. Expose a module-level `settings = Settings()` singleton. Fields: all vars from `.env.example`, grouped by section (LLM, TTS, RAG, Redis, Backend, Engine, Frontend).

**0.5 — scripts/setup_env.sh and setup_env.bat**
Shell script steps:
1. Check Python ≥ 3.11, node ≥ 18, docker available
2. `python -m venv .venv`
3. Activate venv and `pip install -r requirements.txt`
4. `cd frontend && npm install && cd ..`
5. `cp .env.example .env` (skip if .env exists)
6. `docker run -d --name litcast-redis -p 6379:6379 redis:7-alpine` (skip if already running)
7. `mkdir -p books chroma_db episodes`
8. Print: "Setup complete. Edit .env with your API keys, then run scripts/run_dev"

**0.6 — scripts/run_dev.sh and run_dev.bat**
Use `concurrently` (Node) or parallel shell commands to start:
- `uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000` (label: BACKEND, colour: cyan)
- `cd frontend && npm run dev` (label: FRONTEND, colour: magenta)
- Docker Redis check: start if not running (label: REDIS, colour: yellow)
Print startup URLs on launch.

**0.7 — scripts/run_ingest.sh and run_ingest.bat**
Accept `--book <path>` or `--all` flag. Activate venv, run `python -m backend.rag.ingest [args]`.

**0.8 — scripts/run_tests.sh and run_tests.bat**
Run: `pytest backend/tests/ -v --tb=short --cov=backend --cov-report=term-missing`
Then: `cd frontend && npx vitest run`
Print combined summary.

**0.9 — backend/main.py stub**
FastAPI app with health route `GET /health → {"status": "ok", "version": "0.1.0"}`. Import and include all route routers (stubs OK at this stage). Add CORS middleware allowing localhost:5173.

**0.10 — frontend package.json**
React 18, TypeScript, Vite, Tailwind CSS, vitest, @testing-library/react. Add `dev`, `build`, `test` scripts.

### Verification
- `scripts/setup_env` runs without error
- `scripts/run_dev` starts backend and frontend
- `GET http://localhost:8000/health` returns 200
- `GET http://localhost:5173` serves React shell

---

## Phase 1 — LLM Provider Layer

### Goal
Swappable LLM backend. All four providers implemented, router reads from config, agents call a single interface.

### Tasks

**1.1 — backend/llm/base_provider.py**
Implement `LLMMessage` dataclass and abstract `LLMProvider` class exactly as defined in ARCHITECTURE.md §LLM Provider Interface. Add `max_retries: int = 3` and `timeout_seconds: float = 30.0` to base.

**1.2 — backend/llm/providers/anthropic_provider.py**
Implement `AnthropicProvider(LLMProvider)`:
- Use `anthropic.AsyncAnthropic` client
- `complete()`: `messages.create()` with system injected as system param
- `stream()`: `messages.stream()` yielding text deltas
- `provider_name` → `"anthropic"`
- Reads `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL` from settings

**1.3 — backend/llm/providers/openai_provider.py**
Implement `OpenAIProvider(LLMProvider)`:
- Use `openai.AsyncOpenAI` client
- `complete()` and `stream()` via chat completions
- `provider_name` → `"openai"`
- Reads `OPENAI_API_KEY`, `OPENAI_MODEL`

**1.4 — backend/llm/providers/ollama_provider.py**
Implement `OllamaProvider(LLMProvider)`:
- Use `httpx.AsyncClient` to call Ollama REST API (`/api/chat`)
- `complete()`: POST to `{OLLAMA_BASE_URL}/api/chat` with `stream: false`
- `stream()`: POST with `stream: true`, parse NDJSON chunks
- `provider_name` → `"ollama"`
- Reads `OLLAMA_BASE_URL`, `OLLAMA_MODEL`
- On connection error, raise `LLMProviderError` with helpful message ("Is Ollama running?")

**1.5 — backend/llm/providers/lmstudio_provider.py**
Implement `LMStudioProvider(LLMProvider)`:
- LM Studio exposes OpenAI-compatible API — reuse OpenAI client pointed at `LMSTUDIO_BASE_URL`
- `provider_name` → `"lmstudio"`
- Reads `LMSTUDIO_BASE_URL`, `LMSTUDIO_MODEL`

**1.6 — backend/llm/llm_router.py**
```python
def get_llm_provider() -> LLMProvider:
    match settings.llm_provider:
        case "anthropic": return AnthropicProvider()
        case "openai": return OpenAIProvider()
        case "ollama": return OllamaProvider()
        case "lmstudio": return LMStudioProvider()
        case _: raise ValueError(f"Unknown LLM_PROVIDER: {settings.llm_provider}")
```
Expose a cached singleton via `functools.lru_cache`.

**1.7 — backend/tests/test_llm_providers.py**
Tests (use pytest-asyncio, mock HTTP calls with httpx mock or unittest.mock):
- `test_anthropic_complete_returns_string` — mock Anthropic client, assert str returned
- `test_openai_complete_returns_string` — mock OpenAI client
- `test_ollama_complete_returns_string` — mock httpx response
- `test_ollama_stream_yields_chunks` — mock NDJSON response, assert 3+ chunks
- `test_lmstudio_uses_openai_compat` — assert base_url correctly overridden
- `test_router_returns_correct_provider` — parameterize across all 4 values
- `test_ollama_connection_error_raises_helpful` — assert LLMProviderError message contains "Ollama"
- `test_unknown_provider_raises` — assert ValueError on bad LLM_PROVIDER value

**1.8 — GET /test/providers route**
Return JSON: `{llm: {provider, model, status: "ok"|"error"}, tts: {provider, status}}`. LLM status: attempt a 1-token completion ("ping" → "pong"). TTS status: stub for now (Phase 2).

### Verification
- All 8 LLM tests pass
- `GET /test/providers` returns 200 with correct provider name

---

## Phase 2 — TTS Provider Layer

### Goal
Swappable TTS with per-persona voices. `TTS_PROVIDER=none` for transcript-only mode.

### Tasks

**2.1 — backend/tts/base_provider.py**
Implement abstract `TTSProvider` as in ARCHITECTURE.md §TTS Provider Interface. Add `audio_format: str = "mp3"` property.

**2.2 — backend/tts/providers/elevenlabs_provider.py**
- Use `elevenlabs` Python SDK `AsyncElevenLabs`
- `synthesize(text, voice_id)` → MP3 bytes via `client.generate()`
- `get_voice_id(persona_name)` → reads `VOICE_{PERSONA_NAME.upper()}` env var, falls back to `ELEVENLABS_DEFAULT_VOICE`
- `provider_name` → `"elevenlabs"`

**2.3 — backend/tts/providers/openai_tts_provider.py**
- Use `openai.AsyncOpenAI().audio.speech.create()`
- Voice map from `VOICE_*` env vars; voice must be one of: alloy, echo, fable, onyx, nova, shimmer
- Default voice per persona if env var not set: define sensible defaults in code
- `provider_name` → `"openai"`

**2.4 — backend/tts/providers/google_tts_provider.py**
- Use `google.cloud.texttospeech.TextToSpeechAsyncClient`
- `synthesize()` → `SynthesizeSpeechRequest` → return `audio_content` bytes
- Voice ID format: `"en-US-Neural2-A"` etc. — read from `VOICE_*` env vars
- `provider_name` → `"google"`

**2.5 — backend/tts/providers/azure_tts_provider.py**
- Use `azure.cognitiveservices.speech` SDK
- Run synthesis in thread pool executor (SDK is sync)
- `provider_name` → `"azure"`

**2.6 — backend/tts/providers/none_provider.py**
- `synthesize()` → returns `b""` immediately
- `provider_name` → `"none"`
- Used in transcript-only mode and in tests

**2.7 — backend/tts/tts_router.py**
Same pattern as `llm_router.py`. Match on `settings.tts_provider`.

**2.8 — backend/tests/test_tts_providers.py**
- `test_elevenlabs_synthesize_returns_bytes` — mock SDK, assert bytes returned
- `test_openai_tts_synthesize_returns_bytes` — mock SDK
- `test_google_tts_synthesize_returns_bytes` — mock SDK
- `test_none_provider_returns_empty_bytes` — no mock needed
- `test_voice_id_reads_from_env` — set `VOICE_ARCHITECT=xyz`, assert `get_voice_id("architect") == "xyz"`
- `test_voice_id_fallback_when_env_missing` — unset env var, assert non-empty default returned
- `test_router_returns_correct_provider` — parameterize all 5 options

**2.9 — GET /test/ping_tts route**
Call `tts_provider.synthesize("Hello, this is a test.", default_voice)`. Return: `{provider, bytes_returned, audio_b64}` if success, `{error}` if fail.

### Verification
- All 7 TTS tests pass
- `GET /test/ping_tts` returns audio bytes when a real key is present; returns `{provider: "none"}` cleanly with TTS_PROVIDER=none

---

## Phase 3 — RAG Pipeline

### Goal
Books ingested into ChromaDB, persona-biased retrieval working, accessible via test route.

### Tasks

**3.1 — backend/rag/ingest.py**
Implement `BookIngestor`:
- `load_book(path: Path) → list[str]` — dispatch by suffix: `.pdf` → pdfplumber, `.epub` → ebooklib, `.txt` → plain read
- `chunk(pages: list[str]) → list[Document]` — use `RecursiveCharacterTextSplitter(chunk_size=RAG_CHUNK_SIZE, chunk_overlap=RAG_CHUNK_OVERLAP)` from langchain-text-splitters; attach metadata: `{book: slug, chapter: int, chunk_index: int}`
- `embed_and_store(chunks, book_slug)` — get/create ChromaDB collection `f"book_{book_slug}"`, upsert all chunks with embeddings
- `ingest(path: Path)` — orchestrates load → chunk → embed_and_store; print progress
- CLI entrypoint: `if __name__ == "__main__":` parse `--book` / `--all` args, run ingest

**3.2 — backend/rag/embeddings.py**
Implement `get_embedding_fn()` → returns ChromaDB-compatible embedding function:
- `EMBEDDING_PROVIDER=openai` → `chromadb.utils.embedding_functions.OpenAIEmbeddingFunction`
- `EMBEDDING_PROVIDER=nomic` → `chromadb.utils.embedding_functions.OllamaEmbeddingFunction` (model: `nomic-embed-text`)

**3.3 — backend/rag/retriever.py**
Implement `BookRetriever`:
- `query(book_slug, topic, persona_bias_prefix, agent_question, top_k) → list[dict]`
- Constructs: `f"{persona_bias_prefix} Regarding '{topic}' in this book: {agent_question}"`
- Queries ChromaDB collection, returns: `[{text, chapter, chunk_index, distance}]`
- `list_books() → list[str]` — lists all ChromaDB collections with `book_` prefix

**3.4 — backend/tests/test_rag_retrieval.py**
- `test_ingest_sample_book` — ingest `tests/fixtures/sample_book.txt`, assert collection exists with > 0 docs
- `test_query_returns_top_k` — query ingested book, assert len(results) == RAG_TOP_K
- `test_results_have_required_metadata` — assert each result has `text`, `chapter`, `distance`
- `test_persona_bias_shifts_results` — query same topic with two different bias prefixes, assert result sets differ
- `test_list_books_returns_ingested` — after ingest, assert book slug in list_books()
- `test_empty_library_returns_empty_list` — fresh ChromaDB, assert list_books() == []

**3.5 — test fixture**
`backend/tests/fixtures/sample_book.txt` — a 2,000-word public domain excerpt (e.g. first chapter of Pride and Prejudice from Project Gutenberg). Hard-code this text directly in the fixture file.

**3.6 — GET /library route**
Return: `{books: [{slug, title, chunk_count, ingested_at}]}` from ChromaDB metadata.

**3.7 — POST /library/ingest route**
Body: `{filename: str}` — file must exist in `books/`. Runs ingest async, returns `{status: "ingesting", book: slug}`. Progress streamed via SSE on `GET /library/ingest/progress`.

**3.8 — POST /test/rag_query route**
Body: `{book_slug, query, persona_bias_prefix?}`. Returns top-k passages with metadata and similarity scores.

### Verification
- All 6 RAG tests pass
- `GET /library` returns empty list on fresh install
- After running `scripts/run_ingest --book books/sample.pdf`, book appears in `/library`
- `POST /test/rag_query` returns relevant passages

---

## Phase 4 — Agent System

### Goal
Persona YAML loading, AgentBase, HostAgent, GuestAgent, and interrupt scoring all working.

### Tasks

**4.1 — backend/agents/personas/ (all 5 YAML files)**
Write all 5 YAML files following the schema in ARCHITECTURE.md §Persona YAML Schema:
- `architect.yaml` — structural logic, spatial metaphors, engineering rigour
- `feminist_critic.yaml` — power dynamics, gender readings, patriarchal structures
- `scientist.yaml` — factual accuracy, plausibility, scientific method skepticism
- `historian.yaml` — period context, cultural roots, anachronism catching
- `pop_culture_fan.yaml` — tropes, fandom lenses, entertainment value, memes
Each must have: `name, short_id, lens, quirks (4 items), interrupt_threshold, disagreement_style, rag_bias_prefix, system_prompt_addendum, voice_env_key, color_hex`

**4.2 — backend/agents/base_agent.py**
Implement `AgentBase`:
- `__init__(persona_path: Path, llm: LLMProvider, tts: TTSProvider, retriever: BookRetriever)`
- `load_persona(path)` — parse YAML into `PersonaConfig` dataclass
- `build_system_prompt(topic, book_title) → str` — compose from persona fields
- `retrieve_context(topic, question, book_slug) → list[dict]` — calls retriever with persona bias
- `format_rag_context(passages) → str` — formats passages as `[BOOK REFERENCE §Chapter N]: {text}`
- `generate(messages, max_tokens) → str` — calls `self.llm.complete()`
- `speak(text) → bytes` — calls `self.tts.synthesize(text, self.voice_id)`
- `voice_id` property: reads `VOICE_{persona.short_id.upper()}` env var

**4.3 — backend/agents/guest_agent.py**
Implement `GuestAgent(AgentBase)`:
- `score_interrupt(context: SharedContext) → float`:
  ```python
  persona_relevance = cosine_sim(persona.lens, context.last_turn.text)  # simple keyword overlap OK
  disagreement = 1.0 - sentiment_agreement(persona, context.last_turn)  # heuristic OK
  silence_penalty = min(context.silence_counts[self.short_id] / MAX_SILENCE_TURNS, 1.0)
  return persona_relevance * 0.5 + disagreement * 0.3 + silence_penalty * 0.2
  ```
- `generate_response(context: SharedContext, book_slug: str) → AgentTurn`:
  1. RAG query with current topic + last turn as question
  2. Build messages: [system_prompt, context_summary, rag_context, "Your response:"]
  3. Call `self.generate(messages)`
  4. Return `AgentTurn(speaker, text, rag_passages, urgency_score)`
- `INTERRUPT_COOLDOWN_SECONDS` respected: track `last_spoke_at`, refuse interrupt if within cooldown

**4.4 — backend/agents/host_agent.py**
Implement `HostAgent(AgentBase)`:
- No interrupt threshold — host always has priority
- `evaluate_queue(context, interrupt_queue) → str | None`: returns `short_id` to speak, or `None` to host-intervene
  - Intervene if `context.heat_level > HEAT_INTERVENTION_THRESHOLD`
  - Intervene if all guests silent for `MAX_SILENCE_TURNS`
  - Else return `interrupt_queue[0]` if non-empty
- `generate_moderation(context, reason: str) → AgentTurn`: reason ∈ `"heat"|"summary"|"silence"|"redirect"`
- `generate_summary(context) → AgentTurn`: segment summary every `SEGMENT_DURATION_TURNS` turns

**4.5 — backend/memory/shared_context.py**
Implement `SharedContext`:
- Redis-backed using `aioredis` (via `redis.asyncio`)
- `get(session_id) → dict` / `set(session_id, data)` / `update_turn(session_id, turn: AgentTurn)`
- `update_heat(session_id)` — recalculate from last 4 turns' disagreement scores
- `get_recent_turns(session_id, n=6) → list[AgentTurn]`
- TTL set to `REDIS_CONVERSATION_TTL` on every write

**4.6 — backend/tests/test_agent_persona.py**
- `test_all_persona_yamls_valid` — load all 5, assert required fields present
- `test_persona_rag_prefix_in_query` — assert bias prefix appears in retriever call args
- `test_persona_quirks_influence_prompt` — assert quirks appear in system prompt output
- `test_voice_id_reads_env` — set VOICE_ARCHITECT=test123, assert base_agent.voice_id == "test123"

**4.7 — backend/tests/test_host_moderation.py**
- `test_host_intervenes_above_heat_threshold` — set heat_level=0.8, assert evaluate_queue returns None (host speaks)
- `test_host_grants_token_to_queue_head` — heat=0.3, queue=["scientist","historian"], assert "scientist" returned
- `test_host_intervenes_on_total_silence` — all silence_counts at MAX_SILENCE_TURNS, assert intervention
- `test_summary_generated_at_segment_interval` — turn count at multiple of SEGMENT_DURATION_TURNS, assert summary triggered

**4.8 — backend/tests/test_interrupt_scoring.py**
- `test_urgency_formula_weights_sum_to_one` — verify coefficients 0.5+0.3+0.2=1.0
- `test_silence_penalty_increases_with_turns` — 0 turns silent < 2 turns silent < MAX turns silent
- `test_cooldown_prevents_immediate_reinterrupt` — agent just spoke, assert score effectively 0 due to cooldown
- `test_high_disagreement_raises_score` — mock high disagreement, assert score > interrupt_threshold

**4.9 — POST /test/single_agent route**
Body: `{persona: str, book_slug: str, topic: str, last_turn_text: str}`. Runs one GuestAgent.generate_response(), returns: `{speaker, text, rag_passages, urgency_score}`.

### Verification
- All persona YAML tests pass
- All host moderation tests pass
- All interrupt scoring tests pass
- `POST /test/single_agent {persona: "architect", book_slug: "lotr", topic: "the mines of moria", last_turn_text: "..."}` returns a text response citing book passages

---

## Phase 5 — Conversation Engine & CrewAI

### Goal
Full multi-agent free-for-all conversation running end-to-end with CrewAI.

### Tasks

**5.1 — backend/crew/podcast_crew.py**
Implement `PodcastCrew`:
- `__init__(session_id, book_title, topic, persona_ids: list[str])`
- Creates `crewai.Agent` instances for each persona + host
- Host set as `manager_llm` in `crewai.Crew(process=Process.hierarchical)`
- Each guest agent has `tools=[book_rag_tool, thread_read_tool, interrupt_request_tool]` (implement as CrewAI `@tool` functions wrapping backend logic)
- `start()` / `stop()` / `pause()` methods manage crew lifecycle
- Book RAG tool: wraps `BookRetriever.query()` with persona bias from agent context
- Thread read tool: wraps `SharedContext.get_recent_turns()`
- Interrupt request tool: writes agent's `short_id` to `interrupt_queue` in Redis

**5.2 — backend/crew/conversation_engine.py**
Implement `ConversationEngine`:
- `__init__(session_id, crew: PodcastCrew, context: SharedContext)`
- `async run()` — main async loop:
  ```
  while status == "running":
      scores = await asyncio.gather(*[guest.score_interrupt(ctx) for guest in guests])
      queue = sorted agents by score desc, filtered by threshold
      next_speaker = host.evaluate_queue(ctx, queue)
      if next_speaker == "host":
          turn = await host.generate_moderation(ctx, reason)
      else:
          turn = await guests[next_speaker].generate_response(ctx, book_slug)
      audio = await tts.synthesize(turn.text, speaker.voice_id)
      await context.update_turn(session_id, turn)
      await transcript_streamer.emit(turn, audio)
      if ctx.turn_count % SEGMENT_DURATION_TURNS == 0:
          summary = await host.generate_summary(ctx)
          await context.update_turn(session_id, summary)
      await asyncio.sleep(INTERRUPT_COOLDOWN_SECONDS)
  ```
- `pause()` / `resume()` — toggle `status` in shared context
- `stop()` — set status "complete", trigger episode packager

**5.3 — backend/tests/test_conversation_engine.py**
Mock LLM (returns "Mock response about the book."), mock TTS (returns b""), use NoneProvider.
- `test_engine_runs_8_turns` — start engine, run 8 ticks, assert 8 turns in shared context
- `test_host_intervenes_on_heat` — inject high heat after turn 3, assert host turn at turn 4
- `test_silence_penalty_causes_reentry` — set one agent's silence_count to MAX, assert it speaks in next 2 turns
- `test_segment_summary_at_interval` — run SEGMENT_DURATION_TURNS+1 turns, assert summary turn present
- `test_pause_stops_loop` — call pause() after 2 turns, assert no more turns added
- `test_stop_triggers_packager` — call stop(), assert episode_packager.finalize called

**5.4 — POST /session/start route**
Body: `{book_title, book_slug, topic, persona_ids: ["architect", "feminist_critic", ...]}`.
- Validate book_slug exists in ChromaDB
- Validate persona_ids (1–5 valid short_ids)
- Seed `SharedContext` in Redis
- Init `PodcastCrew` and `ConversationEngine`
- Launch `asyncio.create_task(engine.run())`
- Return: `{session_id, status: "running"}`

**5.5 — POST /session/stop and /session/pause routes**
Call `engine.stop()` / `engine.pause()`. Return `{status}`.

### Verification
- All 6 engine tests pass
- `POST /session/start` with valid params starts a session
- Redis shows session key with growing turns
- `POST /session/stop` halts loop cleanly

---

## Phase 6 — API Streaming & Output Pipeline

### Goal
WebSocket streaming of transcript events and audio to frontend. Episode packager.

### Tasks

**6.1 — backend/output/transcript_streamer.py**
Implement `TranscriptStreamer`:
- `emit(turn: AgentTurn, audio_bytes: bytes, session_id: str)`:
  - Publish to Redis pub/sub channel `f"session:{session_id}:events"`
  - Payload: `{type: "turn", speaker, text, color_hex, audio_b64, rag_passages, timestamp}`
- `emit_status(session_id, event_type, data)` — for heat updates, segment markers, status changes

**6.2 — backend/api/websocket.py**
- `WS /ws?session_id={id}`
- Subscribe to Redis channel on connect
- Forward all events to WebSocket client as JSON
- On disconnect: unsubscribe, log
- Ping/pong keepalive every 30s

**6.3 — backend/api/routes/stream.py**
- `GET /stream?session_id={id}` — SSE fallback for clients that prefer SSE over WebSocket
- Same Redis pub/sub subscription, yield as `data: {json}\n\n`

**6.4 — backend/output/episode_packager.py**
Implement `EpisodePackager`:
- Collects all audio chunks during session (in-memory list of `(speaker, bytes)`)
- `finalize(session_id)`:
  1. Concatenate audio chunks with 0.5s silence between speakers (pydub)
  2. Write `episodes/{session_id}.mp3`
  3. Write `episodes/{session_id}.json`: `{book, topic, personas, turns, chapter_markers, duration_seconds}`
  4. Update session status in Redis to "complete"
- `GET /episode/{id}` route: serve MP3 file from `episodes/`

**6.5 — Tests**
- `test_streamer_emits_to_redis` — mock Redis, assert publish called with correct channel + payload
- `test_ws_forwards_redis_events` — mock Redis sub, connect test WebSocket client, assert message received
- `test_packager_writes_mp3_and_json` — mock pydub, assert files written to episodes/

### Verification
- Connect to `ws://localhost:8000/ws?session_id=X`, start session, see turn events in real time
- After stop, `GET /episode/{id}` returns downloadable MP3

---

## Phase 7 — React Radio Dashboard

### Goal
Full frontend: live transcript, guest status, waveform, heat meter, episode controls.

### Tasks

**7.1 — src/types/podcast.ts**
TypeScript interfaces: `AgentTurn`, `PersonaConfig`, `SessionStatus`, `WsEvent`, `EpisodeMetadata`, `LibraryBook`.

**7.2 — src/hooks/useWebSocket.ts**
- Connects to `VITE_BACKEND_WS_URL/ws?session_id={id}`
- Exposes: `{turns, heatLevel, currentSpeaker, status, sendMessage}`
- Reconnects automatically on drop (exponential backoff, max 5 retries)

**7.3 — src/hooks/useAudioPlayer.ts**
- Queues `audio_b64` chunks from WS events
- Plays sequentially using Web Audio API (`AudioContext.decodeAudioData`)
- Exposes: `{isPlaying, currentSpeaker, pause, resume}`

**7.4 — src/components/RadioDashboard.tsx**
Main layout: 3-column on desktop (topic sidebar | transcript | controls), stacked on mobile. Dark theme. Holds session state, passes to children via props.

**7.5 — src/components/GuestStatusRow.tsx**
Row of 5 persona cards. Each card: persona name, lens (one line), avatar placeholder (initials), status badge (SPEAKING 🔴 / THINKING ⏳ / IDLE). Highlight border in persona `color_hex` when speaking. Pulse animation on SPEAKING.

**7.6 — src/components/TranscriptPanel.tsx**
Scrolling transcript. Each turn: persona name badge (persona color), text, small "📖" icon if rag_passages present (hover to see passages). Auto-scroll to bottom on new turn. Smooth CSS transition on append.

**7.7 — src/components/WaveformStrip.tsx**
Web Audio API `AnalyserNode` → 64-bar canvas visualiser. Colour follows current speaker's `color_hex`. Flatlines to grey when no audio.

**7.8 — src/components/HeatMeter.tsx**
Horizontal bar 0–100%. Colour: green (0–40%) → amber (40–70%) → red (70–100%). Label: "Conversation heat". Animates smoothly on change.

**7.9 — src/components/EpisodeControls.tsx**
Buttons: Start (opens modal to pick book + topic + personas), Pause/Resume, Stop. Status badge. "Download Episode" button (active after stop). Export Transcript (downloads JSON).

**7.10 — src/components/TopicSidebar.tsx**
Shows: book title, cover placeholder, current topic, segment number, chapter markers list (grows as episode plays).

**7.11 — frontend/tests/**
Implement tests for RadioDashboard, TranscriptPanel, TestPanel as defined in ARCHITECTURE.md §Test Structure.

### Verification
- Radio dashboard renders at localhost:5173
- Starting a session via UI populates transcript in real time
- Guest cards animate on speaker change
- Waveform responds to audio

---

## Phase 8 — Test Panel & Episode Packager Polish

### Goal
Dev test panel fully functional. Episode packager produces clean output. Full test run green.

### Tasks

**8.1 — src/components/TestPanel.tsx**
Collapsible drawer (shown when `VITE_ENABLE_TEST_PANEL=true`). Sections:
- **Provider status**: `GET /test/providers` on mount, green/red badges, model names, latency ms
- **Topic injector**: book dropdown (from `/library`), topic text field, persona multi-select checkboxes, "Start Session" button
- **Single agent tester**: persona select, book select, topic field, last-turn-text field, "Run Turn" button → shows response + RAG passages used (expandable)
- **RAG explorer**: book select, free-text query, bias prefix text field, "Search" button → table of passages with similarity scores
- **Voice sampler**: per-persona row with "▶ Play sample" button → calls `POST /test/ping_tts` with that persona's voice
- **Heat override**: slider 0.0–1.0 → `POST /session/heat` sets Redis heat_level directly
- **Session JSON viewer**: `GET /session/{id}/debug` → pretty-printed raw shared context

**8.2 — Additional test routes**
- `POST /session/heat` — body: `{session_id, heat_level: float}` — directly sets heat in Redis (test use only, guard with `VITE_ENABLE_TEST_PANEL` check)
- `GET /session/{id}/debug` — returns full raw `SharedContext` dict

**8.3 — Episode packager: chapter markers**
- Host summary turns write a chapter marker to `EpisodePackager.markers: list[{turn, timestamp, summary}]`
- `finalize()` embeds markers in MP3 ID3 tags using `mutagen` (add to requirements.txt)
- JSON output includes `chapter_markers` array

**8.4 — Full test sweep**
Run `scripts/run_tests` and fix any remaining failures. Target: all backend tests green, all frontend tests green. Coverage report: aim for > 70% on `backend/agents/`, `backend/crew/`, `backend/rag/`.

**8.5 — README.md**
Write root `README.md`:
- What LitCast is (2 paragraphs)
- Quick start (setup_env → add API keys → run_ingest → run_dev)
- Provider swap instructions (table from ARCHITECTURE.md)
- How to add a new persona (YAML schema walkthrough)
- How to add a new book (drop in books/, run run_ingest)
- Test panel guide
- Known limitations

### Verification
- `scripts/run_tests` exits 0
- Test panel shows green for all connected providers
- Full episode: start session → 15 turns → stop → download MP3 with chapter markers
- README setup instructions produce a working system on a fresh machine
