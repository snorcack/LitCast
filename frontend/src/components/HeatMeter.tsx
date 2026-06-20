import React from 'react';

interface Props {
  heatLevel: number;
}

export const HeatMeter: React.FC<Props> = ({ heatLevel }) => {
  const percentage = Math.min(100, Math.max(0, heatLevel * 100));

  let colorClass = "bg-green-500";
  if (percentage > 70) colorClass = "bg-red-500";
  else if (percentage > 40) colorClass = "bg-amber-500";

  return (
    <div className="w-full p-4 bg-gray-900 border-b border-gray-800">
      <div className="flex justify-between items-center mb-2">
        <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Conversation Heat</span>
        <span className="text-xs font-mono text-gray-500">{percentage.toFixed(0)}%</span>
      </div>
      <div className="w-full h-2 bg-gray-800 rounded-full overflow-hidden">
        <div
          className={`h-full ${colorClass} transition-all duration-500 ease-out`}
          style={{ width: `${percentage}%` }}
        />
      </div>
    </div>
  );
};
