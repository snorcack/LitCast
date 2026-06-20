import React, { useState } from 'react';
import { useWebSocket } from '../hooks/useWebSocket';
import { useAudioPlayer } from '../hooks/useAudioPlayer';
import { GuestStatusRow } from './GuestStatusRow';
import { TranscriptPanel } from './TranscriptPanel';
import { WaveformStrip } from './WaveformStrip';
import { HeatMeter } from './HeatMeter';
import { EpisodeControls } from './EpisodeControls';
import { TopicSidebar } from './TopicSidebar';
import { PersonaConfig } from '../types/podcast';

const mockPersonas: PersonaConfig[] = [
  { name: "The Architect", short_id: "architect", color_hex: "#D85A30", lens: "Structural design", quirks: [], interrupt_threshold: 0.6, disagreement_style: "", rag_bias_prefix: "", system_prompt_addendum: "", voice_env_key: "" },
  { name: "The Feminist Critic", short_id: "feminist_critic", color_hex: "#8B5FBF", lens: "Power dynamics", quirks: [], interrupt_threshold: 0.6, disagreement_style: "", rag_bias_prefix: "", system_prompt_addendum: "", voice_env_key: "" },
  { name: "The Scientist", short_id: "scientist", color_hex: "#3498DB", lens: "Factual accuracy", quirks: [], interrupt_threshold: 0.6, disagreement_style: "", rag_bias_prefix: "", system_prompt_addendum: "", voice_env_key: "" },
];

export const RadioDashboard: React.FC = () => {
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [bookTitle, setBookTitle] = useState("Pride and Prejudice");
  const [topic, setTopic] = useState("Socio-economic factors in marriage");

  const { turns, heatLevel, currentSpeaker, status, audioQueue, popAudio } = useWebSocket(sessionId);
  const { isPlaying, currentAudioSpeaker, audioContextRef } = useAudioPlayer(audioQueue, popAudio);

  const activeSpeaker = isPlaying ? currentAudioSpeaker : currentSpeaker;
  const activeColor = mockPersonas.find(p => p.short_id === activeSpeaker)?.color_hex || '#FFFFFF';

  const handleStart = async () => {
    try {
      const res = await fetch("http://localhost:8000/session/start", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          book_title: bookTitle,
          book_slug: "sample_book",
          topic: topic,
          persona_ids: mockPersonas.map(p => p.short_id)
        })
      });
      const data = await res.json();
      if (data.session_id) {
        setSessionId(data.session_id);
      }
    } catch (e) {
      console.error(e);
      setSessionId("mock-session");
    }
  };

  const handleStop = async () => {
    if (!sessionId) return;
    try {
      await fetch("http://localhost:8000/session/stop", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ session_id: sessionId })
      });
    } catch (e) { console.error(e); }
  };

  return (
    <div className="flex h-screen w-full bg-black text-gray-200 overflow-hidden font-sans">
      <TopicSidebar bookTitle={bookTitle} topic={topic} segment={1} />

      <div className="flex-1 flex flex-col h-full relative">
        <GuestStatusRow personas={mockPersonas} currentSpeaker={activeSpeaker} />
        <HeatMeter heatLevel={heatLevel} />

        <TranscriptPanel turns={turns} />

        <div className="mt-auto flex flex-col shrink-0 z-10 shadow-[0_-10px_30px_rgba(0,0,0,0.5)]">
          <WaveformStrip audioContext={audioContextRef} isPlaying={isPlaying} colorHex={activeColor} />
          <EpisodeControls
            status={status}
            sessionId={sessionId}
            onStart={handleStart}
            onPauseResume={() => {}}
            onStop={handleStop}
          />
        </div>
      </div>
    </div>
  );
};
