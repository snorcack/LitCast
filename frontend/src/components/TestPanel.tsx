import React, { useState, useEffect } from 'react';

export const TestPanel: React.FC = () => {
  const [providers, setProviders] = useState<any>(null);
  const [isOpen, setIsOpen] = useState(false);
  const enabled = import.meta.env.VITE_ENABLE_TEST_PANEL === 'true';

  useEffect(() => {
    if (enabled) {
      fetch('http://localhost:8000/test/providers')
        .then(res => res.json())
        .then(data => setProviders(data))
        .catch(e => console.error("TestPanel fetch error", e));
    }
  }, [enabled]);

  if (!enabled) return null;

  return (
    <div className={`fixed bottom-0 left-0 w-full bg-gray-900 border-t border-gray-700 transition-transform duration-300 z-50 ${isOpen ? 'translate-y-0' : 'translate-y-[90%]'}`}>
      <div
        className="w-full bg-gray-800 text-center py-1 text-xs font-bold uppercase tracking-widest cursor-pointer hover:bg-gray-700"
        onClick={() => setIsOpen(!isOpen)}
      >
        Developer Test Panel {isOpen ? '▼' : '▲'}
      </div>

      <div className="p-4 h-64 overflow-y-auto flex gap-6">
        <div className="flex-1 border border-gray-700 p-3 rounded">
          <h3 className="font-bold mb-2">Provider Status</h3>
          {providers ? (
            <div className="text-sm flex flex-col gap-2">
              <div className="flex justify-between border-b border-gray-800 pb-1">
                <span>LLM: {providers.llm?.provider}</span>
                <span className={providers.llm?.status === 'ok' ? 'text-green-500' : 'text-red-500'}>
                  {providers.llm?.status}
                </span>
              </div>
              <div className="flex justify-between">
                <span>TTS: {providers.tts?.provider}</span>
                <span className={providers.tts?.status === 'ok' ? 'text-green-500' : 'text-yellow-500'}>
                  {providers.tts?.status}
                </span>
              </div>
            </div>
          ) : (
            <div className="text-sm text-gray-500">Loading...</div>
          )}
        </div>

        <div className="flex-1 border border-gray-700 p-3 rounded opacity-50 pointer-events-none">
          <h3 className="font-bold mb-2">Single Agent Test</h3>
          <div className="text-xs">Select persona, enter topic, see isolated output. (Mocked in UI)</div>
        </div>

        <div className="flex-1 border border-gray-700 p-3 rounded opacity-50 pointer-events-none">
          <h3 className="font-bold mb-2">Heat Override</h3>
          <input type="range" min="0" max="100" className="w-full" />
          <div className="text-xs mt-1">Force Redis heat level. (Mocked in UI)</div>
        </div>
      </div>
    </div>
  );
};
