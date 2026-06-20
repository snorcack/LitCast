import React, { useEffect, useRef } from 'react';

interface Props {
  audioContext: AudioContext | null;
  isPlaying: boolean;
  colorHex: string | null;
}

export const WaveformStrip: React.FC<Props> = ({ audioContext, isPlaying, colorHex }) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const animationRef = useRef<number | null>(null);

  useEffect(() => {
    if (!audioContext || !canvasRef.current) return;

    if (!analyserRef.current && audioContext.state !== 'closed') {
        try {
            analyserRef.current = audioContext.createAnalyser();
            analyserRef.current.fftSize = 128;
        } catch(e) {}
    }

    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const draw = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      const barWidth = (canvas.width / 64) - 1;
      let x = 0;

      for (let i = 0; i < 64; i++) {
        const value = isPlaying ? Math.random() * 255 : 5;
        const percent = value / 255;
        const height = canvas.height * percent;
        const offset = canvas.height - height;

        ctx.fillStyle = isPlaying ? (colorHex || '#888') : '#333';
        ctx.fillRect(x, offset, barWidth, height);
        x += barWidth + 1;
      }

      animationRef.current = requestAnimationFrame(draw);
    };

    draw();

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, [audioContext, isPlaying, colorHex]);

  return (
    <div className="h-16 w-full bg-black flex items-end border-t border-b border-gray-900 overflow-hidden">
      <canvas ref={canvasRef} className="w-full h-full" width={800} height={64} />
    </div>
  );
};
