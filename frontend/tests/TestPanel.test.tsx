import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import { TestPanel } from '../src/components/TestPanel';
import { vi } from 'vitest';
import '@testing-library/jest-dom';

describe('TestPanel', () => {
  beforeEach(() => {
    import.meta.env.VITE_ENABLE_TEST_PANEL = 'true';
    global.fetch = vi.fn(() =>
      Promise.resolve({
        json: () => Promise.resolve({
          llm: { provider: 'testllm', status: 'ok' },
          tts: { provider: 'testtts', status: 'stub' }
        }),
      })
    ) as any;
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('renders test panel and fetches status', async () => {
    render(<TestPanel />);
    expect(screen.getByText(/Developer Test Panel/)).toBeInTheDocument();

    await waitFor(() => {
      expect(screen.getByText(/LLM: testllm/)).toBeInTheDocument();
    });
  });
});
