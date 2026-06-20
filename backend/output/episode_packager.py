import json
from pathlib import Path

class EpisodePackager:
    def __init__(self):
        self.audio_chunks = []
        self.markers = []

    def add_audio_chunk(self, speaker: str, audio_bytes: bytes, turn_index: int = None):
        if audio_bytes:
            self.audio_chunks.append({"speaker": speaker, "audio": audio_bytes})

    def add_marker(self, turn_index: int, timestamp: float, summary: str):
        self.markers.append({"turn": turn_index, "timestamp": timestamp, "summary": summary})

    def finalize(self, session_id: str, context_data: dict = None):
        output_dir = Path("episodes")
        output_dir.mkdir(exist_ok=True)
        # Mock packaging logic to avoid depending on pydub / ffmpeg for now
