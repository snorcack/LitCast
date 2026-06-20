import { useState, useEffect, useRef, useCallback } from 'react';
import { AgentTurn, WsEvent } from '../types/podcast';

export function useWebSocket(sessionId: string | null) {
  const [turns, setTurns] = useState<AgentTurn[]>([]);
  const [heatLevel, setHeatLevel] = useState(0);
  const [currentSpeaker, setCurrentSpeaker] = useState<string | null>(null);
  const [status, setStatus] = useState<string>("idle");
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectCount = useRef(0);

  const [audioQueue, setAudioQueue] = useState<{speaker: string, audio_b64: string}[]>([]);

  const connect = useCallback(() => {
    if (!sessionId) return;

    const wsUrl = import.meta.env.VITE_BACKEND_WS_URL || "ws://localhost:8000/ws";
    const ws = new WebSocket(`${wsUrl}?session_id=${sessionId}`);

    ws.onopen = () => {
      console.log('WS Connected');
      reconnectCount.current = 0;
    };

    ws.onmessage = (event) => {
      try {
        const data: WsEvent = JSON.parse(event.data);
        if (data.type === 'turn' && data.speaker && data.text) {
          const newTurn: AgentTurn = {
            speaker: data.speaker,
            text: data.text,
            rag_passages: data.rag_passages || [],
            urgency_score: data.urgency_score || 0,
            timestamp: data.timestamp || Date.now(),
            color_hex: data.color_hex || '#fff'
          };
          setTurns(prev => [...prev, newTurn]);
          setCurrentSpeaker(data.speaker);

          if (data.audio_b64) {
            setAudioQueue(prev => [...prev, {speaker: data.speaker!, audio_b64: data.audio_b64!}]);
          }
        } else if (data.type === 'status_update') {
           if (data.heat_level !== undefined) setHeatLevel(data.heat_level);
           if (data.status) setStatus(data.status);
        } else if (data.type === 'pong') {
           // Keepalive ack
        }
      } catch (e) {
        console.error("Failed to parse WS message", e);
      }
    };

    ws.onclose = () => {
      console.log('WS Disconnected');
      if (reconnectCount.current < 5 && sessionId) {
        setTimeout(() => {
          reconnectCount.current++;
          connect();
        }, Math.min(1000 * Math.pow(2, reconnectCount.current), 10000));
      }
    };

    wsRef.current = ws;
  }, [sessionId]);

  useEffect(() => {
    connect();

    const interval = setInterval(() => {
        if (wsRef.current?.readyState === WebSocket.OPEN) {
            wsRef.current.send("ping");
        }
    }, 10000);

    return () => {
      clearInterval(interval);
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, [connect]);

  const popAudio = useCallback(() => {
      if (audioQueue.length > 0) {
          const next = audioQueue[0];
          setAudioQueue(prev => prev.slice(1));
          return next;
      }
      return null;
  }, [audioQueue]);

  return { turns, heatLevel, currentSpeaker, status, audioQueue, popAudio };
}
