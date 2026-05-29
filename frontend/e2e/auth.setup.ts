import { test as setup } from "@playwright/test";
import * as fs from "fs";
import * as path from "path";

const authFile = "e2e/.auth/user.json";

setup("authenticate", async ({ page }) => {
  // In CI with real Cognito, perform OIDC login via hosted UI.
  // For local dev (no Cognito), the app auto-authenticates in dev mode.
  const cognitoAuthority = process.env.VITE_COGNITO_AUTHORITY ?? "";

  if (!cognitoAuthority) {
    // Local dev: write empty auth state (app bypasses auth without Cognito)
    fs.mkdirSync(path.dirname(authFile), { recursive: true });
    fs.writeFileSync(authFile, JSON.stringify({ cookies: [], origins: [] }));
    return;
  }

  // CI: navigate to Cognito hosted UI and submit credentials
  await page.goto("/");
  await page.getByRole("button", { name: /sign in/i }).click();

  // Cognito hosted UI
  await page.waitForURL(/cognito.*\/login/);
  await page.fill('input[name="username"]', process.env.E2E_VIEWER_EMAIL ?? "viewer@example.com");
  await page.fill('input[name="password"]', process.env.E2E_VIEWER_PASSWORD ?? "");
  await page.click('input[type="submit"]');

  await page.waitForURL("/");
  await page.context().storageState({ path: authFile });
});
