import "@testing-library/jest-dom";
import { vi } from "vitest";

// Suppress noisy React act() warnings in tests
const originalConsoleError = console.error;
console.error = (...args: unknown[]) => {
  if (typeof args[0] === "string" && args[0].includes("act(")) return;
  originalConsoleError(...args);
};

export { vi };
