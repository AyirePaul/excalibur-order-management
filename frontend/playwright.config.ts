import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "html",
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL ?? "http://localhost:5173",
    trace: "on-first-retry",
  },
  projects: [
    // Auth setup projects
    {
      name: "setup-viewer",
      testMatch: /auth\.setup\.ts/,
    },
    {
      name: "setup-editor",
      testMatch: /auth\.editor\.setup\.ts/,
    },
    // Test projects — viewer tests (read-only, uses viewer auth state)
    {
      name: "chromium-viewer",
      use: {
        ...devices["Desktop Chrome"],
        storageState: "e2e/.auth/user.json",
      },
      dependencies: ["setup-viewer"],
      testMatch: /orders\.spec\.ts/,
    },
    // Test projects — editor tests (mutating, uses editor auth state)
    {
      name: "chromium-editor",
      use: {
        ...devices["Desktop Chrome"],
        storageState: "e2e/.auth/editor.json",
      },
      dependencies: ["setup-editor"],
      testMatch: /orders\.editor\.spec\.ts/,
    },
  ],
  webServer: process.env.CI
    ? undefined
    : {
        command: "npm run dev",
        url: "http://localhost:5173",
        reuseExistingServer: !process.env.CI,
      },
});
