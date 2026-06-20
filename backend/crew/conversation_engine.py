import asyncio
from backend.crew.podcast_crew import PodcastCrew
from backend.memory.shared_context import SharedContext
from backend.output.transcript_streamer import TranscriptStreamer
from backend.output.episode_packager import EpisodePackager
from backend.config import settings

class ConversationEngine:
    def __init__(self, session_id: str, crew: PodcastCrew, context: SharedContext):
        self.session_id = session_id
        self.crew = crew
        self.context = context
        self.status = "running"
        self.transcript_streamer = TranscriptStreamer()
        self.episode_packager = EpisodePackager()

    async def run(self):
        ctx_data = await self.context.get(self.session_id)
        ctx_data["status"] = "running"
        await self.context.set(self.session_id, ctx_data)

        while self.status == "running":
            ctx_data = await self.context.get(self.session_id)
            if ctx_data.get("status") != "running":
                self.status = ctx_data.get("status", "idle")
                break

            scores_tasks = [guest.score_interrupt(self.context, self.session_id) for guest in self.crew.guests_backend]
            scores = await asyncio.gather(*scores_tasks)

            queue_items = []
            for i, guest in enumerate(self.crew.guests_backend):
                if scores[i] >= guest.persona.interrupt_threshold:
                    queue_items.append((guest.short_id, scores[i]))

            queue_items.sort(key=lambda x: x[1], reverse=True)
            interrupt_queue = [x[0] for x in queue_items]

            next_speaker_id = await self.crew.host_backend.evaluate_queue(self.context, self.session_id, interrupt_queue)

            if next_speaker_id is None:
                turn = await self.crew.host_backend.generate_moderation(self.context, self.session_id, "heat or silence")
                speaker_agent = self.crew.host_backend
            else:
                guest = next((g for g in self.crew.guests_backend if g.short_id == next_speaker_id), None)
                if not guest:
                    turn = await self.crew.host_backend.generate_moderation(self.context, self.session_id, "fallback")
                    speaker_agent = self.crew.host_backend
                else:
                    turn = await guest.generate_response(self.context, self.session_id)
                    speaker_agent = guest

            audio = await speaker_agent.speak(turn.text)
            await self.context.update_turn(self.session_id, turn)

            try:
                await self.transcript_streamer.emit(turn, audio, self.session_id)
            except Exception:
                pass

            ctx_data = await self.context.get(self.session_id)
            if ctx_data.get("turn_count", 0) % settings.segment_duration_turns == 0:
                summary = await self.crew.host_backend.generate_summary(self.context, self.session_id)
                await self.context.update_turn(self.session_id, summary)

            await asyncio.sleep(settings.interrupt_cooldown_seconds)

    async def pause(self):
        self.status = "paused"
        ctx = await self.context.get(self.session_id)
        ctx["status"] = "paused"
        await self.context.set(self.session_id, ctx)

    async def resume(self):
        self.status = "running"
        ctx = await self.context.get(self.session_id)
        ctx["status"] = "running"
        await self.context.set(self.session_id, ctx)

    async def stop(self):
        self.status = "complete"
        ctx = await self.context.get(self.session_id)
        ctx["status"] = "complete"
        await self.context.set(self.session_id, ctx)
        self.episode_packager.finalize(self.session_id)
