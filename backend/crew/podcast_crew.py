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

        # We need a proper host persona, architect was a dummy. Let's create a minimal host inline or default
        # The prompt says: "HostAgent: moderation, turn management".
        # For base_agent initialization, it needs a valid yaml file. We can create one.
        host_yaml = Path("backend/agents/personas/host.yaml")
        if not host_yaml.exists():
            with open(host_yaml, "w") as f:
                f.write("""name: "The Host"
short_id: host
lens: "Moderation"
quirks: ["Keeps time", "Summarizes", "Interrupts when hot", "Neutral"]
interrupt_threshold: 1.0
disagreement_style: "neutral"
rag_bias_prefix: ""
system_prompt_addendum: "You are the Host."
voice_env_key: VOICE_HOST
color_hex: "#FFFFFF"
""")
        self.host_backend = HostAgent(host_yaml, self.llm_provider, self.tts_provider, self.retriever)

        self.guests_backend = []
        for pid in persona_ids:
            path = Path(f"backend/agents/personas/{pid}.yaml")
            self.guests_backend.append(GuestAgent(path, self.llm_provider, self.tts_provider, self.retriever))
