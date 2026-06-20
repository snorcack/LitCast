import React from 'react';
import { PersonaConfig } from '../types/podcast';

interface Props {
  personas: PersonaConfig[];
  currentSpeaker: string | null;
}

export const GuestStatusRow: React.FC<Props> = ({ personas, currentSpeaker }) => {
  return (
    <div className="flex gap-4 overflow-x-auto p-4 bg-gray-900 w-full shrink-0 items-center justify-start border-b border-gray-800">
      {personas.map(p => {
        const isSpeaking = currentSpeaker === p.short_id;
        return (
          <div
            key={p.short_id}
            className={`w-48 p-3 rounded-lg border-2 transition-all duration-300 ${isSpeaking ? 'scale-105 shadow-[0_0_15px_rgba(0,0,0,0.5)]' : 'opacity-70 scale-95 border-gray-700'}`}
            style={{ borderColor: isSpeaking ? p.color_hex : undefined, boxShadow: isSpeaking ? `0 0 15px ${p.color_hex}40` : 'none' }}
          >
            <div className="flex items-center gap-2 mb-2">
              <div
                className="w-8 h-8 rounded-full flex items-center justify-center font-bold text-white shadow-sm"
                style={{ backgroundColor: p.color_hex }}
              >
                {p.name.substring(0, 2).toUpperCase()}
              </div>
              <div className="font-bold text-sm text-gray-100 truncate">{p.name}</div>
            </div>

            <div className="text-xs text-gray-400 h-8 overflow-hidden text-ellipsis line-clamp-2 leading-tight">
              {p.lens}
            </div>

            <div className="mt-3 flex items-center justify-between">
              <span className={`text-[10px] font-bold px-2 py-1 rounded-full ${isSpeaking ? 'bg-red-900/50 text-red-400 animate-pulse' : 'bg-gray-800 text-gray-500'}`}>
                {isSpeaking ? '🔴 SPEAKING' : 'IDLE'}
              </span>
            </div>
          </div>
        );
      })}
    </div>
  );
};
