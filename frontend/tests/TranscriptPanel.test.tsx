import React from 'react';
import { render, screen } from '@testing-library/react';
import { TranscriptPanel } from '../src/components/TranscriptPanel';
import '@testing-library/jest-dom';

describe('TranscriptPanel', () => {
  it('renders waiting message when empty', () => {
    render(<TranscriptPanel turns={[]} />);
    expect(screen.getByText('Waiting for session to start...')).toBeInTheDocument();
  });

  it('renders turns correctly', () => {
    const turns = [
      { speaker: 'architect', text: 'Structural integrity is key.', color_hex: '#D85A30', timestamp: Date.now() / 1000, rag_passages: [], urgency_score: 1.0 }
    ];
    render(<TranscriptPanel turns={turns} />);
    expect(screen.getByText('Structural integrity is key.')).toBeInTheDocument();
    expect(screen.getByText('ARCHITECT')).toBeInTheDocument();
  });
});
