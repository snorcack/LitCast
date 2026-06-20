import React from 'react';

interface Props {
  status: string;
  sessionId: string | null;
  onStart: () => void;
  onPauseResume: () => void;
  onStop: () => void;
}

export const EpisodeControls: React.FC<Props> = ({ status, sessionId, onStart, onPauseResume, onStop }) => {
  return (
    <div className="p-4 bg-gray-950 flex flex-col gap-3">
      <div className="flex items-center gap-4">
        {status === 'idle' || status === 'complete' ? (
          <button
            onClick={onStart}
            className="flex-1 bg-blue-600 hover:bg-blue-500 text-white font-bold py-3 px-4 rounded-lg transition-colors"
          >
            Start New Session
          </button>
        ) : (
          <>
            <button
              onClick={onPauseResume}
              className="flex-1 bg-gray-700 hover:bg-gray-600 text-white font-bold py-3 px-4 rounded-lg transition-colors"
            >
              {status === 'paused' ? '▶ Resume' : '⏸ Pause'}
            </button>
            <button
              onClick={onStop}
              className="flex-1 bg-red-900/80 hover:bg-red-800 text-white font-bold py-3 px-4 rounded-lg transition-colors border border-red-700"
            >
              ⏹ Stop
            </button>
          </>
        )}
      </div>

      {status === 'complete' && sessionId && (
        <a
          href={`http://localhost:8000/episode/${sessionId}`}
          target="_blank" rel="noreferrer"
          className="w-full bg-emerald-700 hover:bg-emerald-600 text-center text-white font-bold py-2 px-4 rounded-lg transition-colors text-sm"
        >
          Download MP3 Episode
        </a>
      )}

      <div className="flex justify-center mt-2">
        <span className="text-[10px] uppercase font-bold text-gray-600 tracking-widest px-3 py-1 bg-gray-900 rounded-full">
          STATUS: {status}
        </span>
      </div>
    </div>
  );
};
