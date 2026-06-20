import { useState, useEffect, useRef, useCallback } from 'react';

export function useAudioPlayer(audioQueue: {speaker: string, audio_b64: string}[], popAudio: () => {speaker: string, audio_b64: string} | null) {
  const audioContextRef = useRef<AudioContext | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentAudioSpeaker, setCurrentAudioSpeaker] = useState<string | null>(null);
  const isProcessing = useRef(false);

  useEffect(() => {
    if (!audioContextRef.current) {
      audioContextRef.current = new (window.AudioContext || (window as any).webkitAudioContext)();
    }
  }, []);

  const playNext = useCallback(async () => {
    if (isProcessing.current || audioQueue.length === 0 || !audioContextRef.current) return;

    isProcessing.current = true;
    const nextItem = popAudio();
    if (!nextItem) {
        isProcessing.current = false;
        return;
    }

    try {
      const binaryString = window.atob(nextItem.audio_b64);
      const len = binaryString.length;
      const bytes = new Uint8Array(len);
      for (let i = 0; i < len; i++) {
          bytes[i] = binaryString.charCodeAt(i);
      }

      const audioBuffer = await audioContextRef.current.decodeAudioData(bytes.buffer);
      const source = audioContextRef.current.createBufferSource();
      source.buffer = audioBuffer;
      source.connect(audioContextRef.current.destination);

      setCurrentAudioSpeaker(nextItem.speaker);
      setIsPlaying(true);

      source.onended = () => {
        setIsPlaying(false);
        setCurrentAudioSpeaker(null);
        isProcessing.current = false;
        playNext();
      };

      source.start();
    } catch (e) {
      console.error("Audio playback failed", e);
      isProcessing.current = false;
      playNext();
    }
  }, [audioQueue, popAudio]);

  useEffect(() => {
    if (!isProcessing.current && audioQueue.length > 0) {
        playNext();
    }
  }, [audioQueue, playNext]);

  return { isPlaying, currentAudioSpeaker, audioContextRef: audioContextRef.current };
}
