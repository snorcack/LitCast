export interface AgentTurn {
    speaker: string;
    text: string;
    rag_passages: string[];
    urgency_score: number;
    timestamp: number;
    color_hex: string;
}

export interface PersonaConfig {
    name: string;
    short_id: string;
    lens: string;
    quirks: string[];
    interrupt_threshold: number;
    disagreement_style: string;
    rag_bias_prefix: string;
    system_prompt_addendum: string;
    voice_env_key: string;
    color_hex: string;
}

export interface SessionStatus {
    session_id: string;
    book_title: string;
    book_slug: string;
    topic: string;
    segment: number;
    heat_level: number;
    current_speaker: string | null;
    status: "idle" | "running" | "paused" | "complete";
}

export interface WsEvent {
    type: string;
    speaker?: string;
    text?: string;
    color_hex?: string;
    audio_b64?: string;
    rag_passages?: string[];
    timestamp?: number;
    [key: string]: any;
}

export interface EpisodeMetadata {
    book: string;
    topic: string;
    personas: string[];
    turns: AgentTurn[];
    chapter_markers: {turn: number, timestamp: number, summary: string}[];
    duration_seconds: number;
}

export interface LibraryBook {
    slug: string;
    title: string;
    chunk_count: number;
    ingested_at: string;
}
