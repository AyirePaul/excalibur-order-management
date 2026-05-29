import { test, expect } from "@playwright/test";

// Viewer-role tests — read-only operations only.
// The playwright.config.ts chromium-viewer project supplies viewer auth state.

test.describe("Viewer role", () => {
  test("can view orders list", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("heading", { name: /orders/i })).toBeVisible();
  });

  test("cannot see New Order button (viewer has no editor role)", async ({ page }) => {
    // In local dev mode everyone is editor — skip this check
    if (!process.env.VITE_COGNITO_AUTHORITY) {
      test.skip();
      return;
    }
    await page.goto("/");
    await expect(page.getByRole("button", { name: /new order/i })).not.toBeVisible();
  });

  test("can view combine page", async ({ page }) => {
    await page.goto("/combine");
    await expect(page.getByRole("heading", { name: /combine/i })).toBeVisible();
  });

  test("can view reports page", async ({ page }) => {
    await page.goto("/reports");
    await expect(page.getByRole("heading", { name: /monthly report/i })).toBeVisible();
  });
});
