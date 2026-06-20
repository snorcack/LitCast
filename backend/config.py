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
