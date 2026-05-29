import { expect, test } from "@playwright/test";

/** Runs only under playwright.prod.config.ts (`next start`, NODE_ENV=production). */

test.describe("Internal gates (production-like)", () => {
  test("/demo returns 404 outside development", async ({ request }) => {
    const res = await request.get("/demo", { maxRedirects: 0 });
    expect(res.status()).toBe(404);
  });

  test("/internal/entitlements returns 404 without token", async ({ request }) => {
    const res = await request.get("/internal/entitlements", { maxRedirects: 0 });
    expect(res.status()).toBe(404);
  });

  test("retired /debug/founder-review returns 404", async ({ request }) => {
    const res = await request.get("/debug/founder-review", { maxRedirects: 0 });
    expect(res.status()).toBe(404);
  });
});
