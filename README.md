# LitCast

LitCast is a multi-agent AI podcast system where 4–5 persona-driven guest agents debate books in a free-for-all format, moderated by a host agent. Agents retrieve evidence from a pre-indexed RAG library, generate speech via a swappable LLM backend, and produce audio via a swappable cloud TTS service. A React radio dashboard streams the live transcript, agent status, and playback.

This system combines CrewAI for agent orchestration, ChromaDB for RAG, Redis for shared conversation state, and FastAPI for real-time WebSocket streaming.

## Quick Start

1. Run the setup script to create your virtual environment and install dependencies:
   ```bash
   ./scripts/setup_env.sh
   ```
2. Edit `.env` to include your API keys (e.g. OpenAI, Anthropic, ElevenLabs).
3. Place any books (PDF, EPUB, TXT) into the `books/` directory, then ingest them:
   ```bash
   ./scripts/run_ingest.sh --all
   ```
4. Start the application stack (FastAPI backend + Vite React frontend):
   ```bash
   ./scripts/run_dev.sh
   ```

## Swapping Providers

You can swap LLM or TTS providers simply by updating your `.env` file without changing code.

| Component | Env Var | Options |
|-----------|---------|---------|
| **LLM** | `LLM_PROVIDER` | `ollama`, `lmstudio`, `anthropic`, `openai` |
| **TTS** | `TTS_PROVIDER` | `elevenlabs`, `openai`, `google`, `azure`, `none` |

## Adding a Persona

Personas are defined in `backend/agents/personas/`. Create a new YAML file:
```yaml
name: "The Comedian"
short_id: comedian
lens: "Humor, satire, and absurdity"
quirks:
  - "Finds the funniest angle"
interrupt_threshold: 0.65
disagreement_style: "sarcastic"
rag_bias_prefix: "Looking for irony in:"
system_prompt_addendum: "You are a comedian..."
voice_env_key: VOICE_COMEDIAN
color_hex: "#F1C40F"
```

## Adding a Book

Drop a `.pdf`, `.epub`, or `.txt` file into the `books/` folder and run `./scripts/run_ingest.sh --book books/my_book.pdf`. The RAG pipeline will automatically chunk, embed, and store it in the local ChromaDB database.

## Test Panel

When `VITE_ENABLE_TEST_PANEL=true`, the React dashboard displays a collapsible developer drawer that allows you to ping providers, inject topics, adjust conversation heat, and inspect the raw Redis shared context state.

## Known Limitations

- RAG context window size must be tuned to your LLM's maximum token limit.
- The `ConversationEngine` free-for-all loop uses a heuristic interruption model; highly overlapping lenses may cause agents to interrupt frequently.
- TTS services can introduce significant latency compared to the local LLM.
