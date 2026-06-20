from abc import ABC, abstractmethod

class TTSProvider(ABC):
    audio_format: str = "mp3"

    @abstractmethod
    async def synthesize(self, text: str, voice_id: str) -> bytes:
        pass

    @abstractmethod
    def get_voice_id(self, persona_name: str) -> str:
        pass

    @property
    @abstractmethod
    def provider_name(self) -> str:
        pass
