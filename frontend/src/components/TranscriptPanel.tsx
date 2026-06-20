import React, { useEffect, useRef } from 'react';
import { AgentTurn } from '../types/podcast';

interface Props {
  turns: AgentTurn[];
}

export const TranscriptPanel: React.FC<Props> = ({ turns }) => {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (containerRef.current) {
      containerRef.current.scrollTop = containerRef.current.scrollHeight;
    }
  }, [turns]);

  return (
    <div ref={containerRef} className="flex-1 overflow-y-auto p-6 space-y-6 bg-gray-950 scroll-smooth">
      {turns.length === 0 ? (
        <div className="h-full flex items-center justify-center text-gray-600 italic">
          Waiting for session to start...
        </div>
      ) : (
        turns.map((turn, i) => (
          <div key={i} className="flex flex-col gap-1 max-w-3xl mx-auto w-full animate-fade-in-up">
            <div className="flex items-center gap-2">
              <span
                className="text-xs font-bold px-2 py-0.5 rounded-md text-gray-900"
                style={{ backgroundColor: turn.color_hex }}
              >
                {turn.speaker.toUpperCase()}
              </span>
              <span className="text-[10px] text-gray-500">
                {new Date(turn.timestamp * 1000).toLocaleTimeString()}
              </span>
              {turn.rag_passages && turn.rag_passages.length > 0 && (
                <div className="group relative cursor-help">
                  <span className="text-sm">📖</span>
                  <div className="absolute hidden group-hover:block bottom-full left-0 mb-2 w-64 p-3 bg-gray-800 border border-gray-700 rounded shadow-xl text-xs text-gray-300 z-10">
                    <div className="font-bold mb-1 text-gray-100">References:</div>
                    <ul className="list-disc pl-4 space-y-1">
                      {turn.rag_passages.map((p, j) => (
                        <li key={j} className="line-clamp-3">{p}</li>
                      ))}
                    </ul>
                  </div>
                </div>
              )}
            </div>
            <div className="text-gray-300 leading-relaxed text-sm p-3 rounded-lg bg-gray-900/50 border border-gray-800/50">
              {turn.text}
            </div>
          </div>
        ))
      )}
    </div>
  );
};
