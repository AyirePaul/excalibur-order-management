import { test as setup } from "@playwright/test";
import * as fs from "fs";
import * as path from "path";

const authFile = "e2e/.auth/editor.json";

setup("authenticate as editor", async ({ page }) => {
  const cognitoAuthority = process.env.VITE_COGNITO_AUTHORITY ?? "";

  if (!cognitoAuthority) {
    // Local dev: write empty auth state (app auto-authenticates as editor in dev mode)
    fs.mkdirSync(path.dirname(authFile), { recursive: true });
    fs.writeFileSync(authFile, JSON.stringify({ cookies: [], origins: [] }));
    return;
  }

  // CI: log in as editor using Cognito hosted UI
  await page.goto("/");
  await page.getByRole("button", { name: /sign in/i }).click();

  await page.waitForURL(/cognito.*\/login/);
  await page.fill('input[name="username"]', process.env.E2E_EDITOR_EMAIL ?? "editor@example.com");
  await page.fill('input[name="password"]', process.env.E2E_EDITOR_PASSWORD ?? "");
  await page.click('input[type="submit"]');

  await page.waitForURL("/");
  await page.context().storageState({ path: authFile });
});
