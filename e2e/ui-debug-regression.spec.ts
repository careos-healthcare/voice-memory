import { expect, test } from "@playwright/test";

const LOCKED_INTERNAL_PATHS = [
  "/internal/entitlements",
  "/internal/founder-review",
  "/internal/behavior-truth",
] as const;

const RETIRED_DEBUG_PATHS = [
  "/debug/entitlements",
  "/debug/founder-review",
  "/debug/resurfacing-metrics",
] as const;

test.describe("Internal route guard regression", () => {
  for (const path of LOCKED_INTERNAL_PATHS) {
    test(`${path} returns 404 without token`, async ({ request }) => {
      const res = await request.get(path, { maxRedirects: 0 });
      expect(res.status(), `expected 404 for locked ${path}`).toBe(404);
      const body = await res.text();
      expect(body.length).toBeLessThan(5000);
      expect(body).not.toMatch(/Instrumentation|node:util\/types/i);
    });
  }

  for (const path of RETIRED_DEBUG_PATHS) {
    test(`retired ${path} returns 404`, async ({ request }) => {
      const res = await request.get(path, { maxRedirects: 0 });
      expect(res.status()).toBe(404);
    });
  }

  test("/launch returns 404 without token", async ({ request }) => {
    const res = await request.get("/launch", { maxRedirects: 0 });
    expect(res.status()).toBe(404);
  });
});
