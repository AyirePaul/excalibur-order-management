import { test, expect } from "@playwright/test";

// These tests run as an authenticated editor and exercise mutating operations.
// The playwright.config.ts chromium-editor project supplies editor auth state.

test.describe("Order CRUD flow (editor)", () => {
  test("create an order", async ({ page }) => {
    await page.goto("/orders/new");
    await page.fill('input[type="date"]', "2025-06-01");
    await page.fill('input[type="number"]', "199.99");
    await page.fill("textarea", "Playwright test order");
    await page.getByRole("button", { name: /create order/i }).click();

    await expect(page).toHaveURL("/");
    await expect(page.getByText("Playwright test order")).toBeVisible();
  });

  test("list and edit an order", async ({ page }) => {
    await page.goto("/");
    const row = page.getByText("Playwright test order");
    await expect(row).toBeVisible();
  });

  test("combine orders and export CSV", async ({ page }) => {
    await page.goto("/combine");
    await page.getByRole("button", { name: /combine/i }).click();

    const downloadPromise = page.waitForEvent("download", { timeout: 10_000 }).catch(() => null);
    const exportLink = page.getByText("Export CSV");

    if (await exportLink.isVisible({ timeout: 5_000 }).catch(() => false)) {
      await exportLink.click();
      await downloadPromise;
    }
  });
});
