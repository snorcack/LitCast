import React from 'react';

interface Props {
  bookTitle: string;
  topic: string;
  segment: number;
}

export const TopicSidebar: React.FC<Props> = ({ bookTitle, topic, segment }) => {
  return (
    <div className="w-64 bg-gray-900 border-r border-gray-800 p-6 flex flex-col gap-6 hidden md:flex shrink-0">
      <div className="flex flex-col items-center">
        <div className="w-32 h-48 bg-gray-800 rounded shadow-2xl mb-4 border border-gray-700 flex items-center justify-center text-4xl text-gray-700">
          📖
        </div>
        <h2 className="font-bold text-center text-lg text-gray-100 leading-tight mb-1">{bookTitle || "Select a book..."}</h2>
        <div className="text-xs text-blue-400 font-bold uppercase tracking-wider">Current Book</div>
      </div>

      <div className="bg-gray-950 p-4 rounded-lg border border-gray-800">
        <div className="text-[10px] text-gray-500 uppercase font-bold tracking-wider mb-2">Discussing</div>
        <div className="text-sm text-gray-300 leading-snug">
          {topic || "Waiting for topic..."}
        </div>
      </div>

      <div className="mt-auto">
        <div className="flex items-center gap-2 mb-3">
          <div className="w-2 h-2 rounded-full bg-red-500 animate-pulse"></div>
          <div className="text-xs font-bold text-gray-400 uppercase tracking-widest">Live Segment {segment}</div>
        </div>
        <div className="text-[10px] text-gray-600">
          LitCast Virtual Book Podcast System
        </div>
      </div>
    </div>
  );
};
