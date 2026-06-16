import { test, expect } from "@playwright/test";

test.describe("Guest-first auth validation", () => {
  test("launch does not show email auth modal", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByTestId("email-code-auth-modal")).toHaveCount(0);
  });

  test("record page has no email modal on load", async ({ page }) => {
    await page.goto("/record");
    await page.waitForTimeout(500);
    await expect(page.getByTestId("email-code-auth-modal")).toHaveCount(0);
  });

  test("account page does not auto-open email modal", async ({ page }) => {
    await page.goto("/account");
    await page.waitForTimeout(500);
    await expect(page.getByTestId("email-code-auth-modal")).toHaveCount(0);
  });

  test("export does not auto-open email modal", async ({ page }) => {
    await page.goto("/export");
    await page.waitForTimeout(500);
    await expect(page.getByTestId("email-code-auth-modal")).toHaveCount(0);
  });
});
