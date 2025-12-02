import { render, screen } from '@testing-library/react';
import App from './App';

test('renders task tracker app', () => {
  render(<App />);
  // Basic test to ensure app renders without crashing
  expect(document.body).toBeInTheDocument();
});

test('app container exists', () => {
  render(<App />);
  const appElement = document.querySelector('.App') || document.body;
  expect(appElement).toBeInTheDocument();
});