import React from 'react';
import { render, screen } from '@testing-library/react';
import { RadioDashboard } from '../src/components/RadioDashboard';
import '@testing-library/jest-dom';

window.matchMedia = window.matchMedia || function() {
    return { matches: false, addListener: function() {}, removeListener: function() {} };
};

(window as any).AudioContext = class {
  state = 'closed';
  createAnalyser() { return { fftSize: 128 }; }
  decodeAudioData() { return Promise.resolve({}); }
};

describe('RadioDashboard', () => {
  it('renders start button initially', () => {
    render(<RadioDashboard />);
    expect(screen.getByText('Start New Session')).toBeInTheDocument();
  });

  it('shows book title in sidebar', () => {
    render(<RadioDashboard />);
    expect(screen.getByText('Pride and Prejudice')).toBeInTheDocument();
  });
});
