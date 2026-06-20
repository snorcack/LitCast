from backend.config import settings

class BookRetriever:
    def __init__(self):
        pass

    def query(self, book_slug: str, topic: str, persona_bias_prefix: str, agent_question: str, top_k: int = None) -> list[dict]:
        return []

    def list_books(self) -> list[dict]:
        return []
