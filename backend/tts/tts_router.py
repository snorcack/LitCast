import functools
from backend.config import settings
from backend.tts.base_provider import TTSProvider
from backend.tts.providers.none_provider import NoneProvider

@functools.lru_cache()
def get_tts_provider() -> TTSProvider:
    return NoneProvider()
