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
