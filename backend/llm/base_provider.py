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
