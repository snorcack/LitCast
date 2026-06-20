from backend.tts.base_provider import TTSProvider

class NoneProvider(TTSProvider):
    @property
    def provider_name(self) -> str:
        return "none"

    async def synthesize(self, text: str, voice_id: str) -> bytes:
        return b""

    def get_voice_id(self, persona_name: str) -> str:
        return "none"
