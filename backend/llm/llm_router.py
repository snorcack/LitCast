import functools
from backend.config import settings
from backend.llm.base_provider import LLMProvider
from backend.llm.providers.none_provider import NoneProvider

@functools.lru_cache()
def get_llm_provider() -> LLMProvider:
    return NoneProvider()
