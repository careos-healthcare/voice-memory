import { expect, test } from "@playwright/test";

/** UI smoke via HTTP — no browser binary required in CI. */
test.describe("UI smoke", () => {
  test("homepage HTML includes recorder anchor", async ({ request }) => {
    const res = await request.get("/");
    expect(res.ok()).toBeTruthy();
    const html = await res.text();
    expect(html).toContain('id="recorder"');
    expect(html).toContain("ArchiveMe");
    expect(html).toContain("See what keeps coming back.");
    expect(html).toContain("Start the 3-day proof challenge");
    expect(html).toContain("ChatGPT helps you think today");
    expect(html).not.toMatch(/href="\/internal/);
  });

  test("record route returns capture shell and privacy line", async ({ request }) => {
    const res = await request.get("/record");
    expect(res.ok()).toBeTruthy();
    const html = await res.text();
    expect(html).toMatch(/Voice capture|record|mic/i);
    expect(html).toMatch(/device|private|local/i);
  });

  test("pricing SSR includes Free Pro and billing state", async ({ request }) => {
    const res = await request.get("/pricing");
    expect(res.ok()).toBeTruthy();
    const html = await res.text();
    expect(html).toContain("data-pricing-ssr");
    expect(html).toContain('data-pricing-plan="free"');
    expect(html).toContain('data-pricing-plan="pro"');
    expect(html).toMatch(/data-billing-state="(configured|disabled)"/);
    expect(html).toContain("Free");
    expect(html).toContain("Pro");
    expect(html).toMatch(/Checkout (available|unavailable)/i);
  });

  test("pricing cancel SSR shows cancel copy", async ({ request }) => {
    const res = await request.get("/pricing?checkout=cancel");
    expect(res.ok()).toBeTruthy();
    const html = await res.text();
    expect(html).toContain("data-checkout-cancel");
    expect(html).toMatch(/canceled|cancelled/i);
  });

  test("journal page includes sync status marker", async ({ request }) => {
    const res = await request.get("/journal");
    expect(res.ok()).toBeTruthy();
    const html = await res.text();
    expect(html).toMatch(/Journal/i);
    expect(html).toContain("data-sync-status");
  });

  test("memory page loads without debug nav", async ({ request }) => {
    const res = await request.get("/memory");
    expect(res.ok()).toBeTruthy();
    const html = await res.text();
    expect(html).not.toMatch(/href="\/internal/);
    expect(html).toMatch(/memory|return|reflection/i);
  });

  test("memory route loads resurfacing surface", async ({ request }) => {
    const res = await request.get("/memory");
    expect(res.ok()).toBeTruthy();
    const html = await res.text();
    expect(html).toMatch(/memory/i);
    expect(html).toContain("ArchiveMe");
  });

  test("threads page uses compact thread list markers", async ({ request }) => {
    const res = await request.get("/threads");
    expect(res.ok()).toBeTruthy();
    const html = await res.text();
    expect(html).toMatch(/thread|Worth returning/i);
    expect(html).not.toMatch(/href="\/internal/);
  });

  test("account page includes delete confirmation phrase", async ({ request }) => {
    const res = await request.get("/account");
    expect(res.ok()).toBeTruthy();
    const html = await res.text();
    expect(html).toMatch(/delete account/i);
  });

  test("export page includes trust copy", async ({ request }) => {
    const res = await request.get("/export");
    expect(res.ok()).toBeTruthy();
    const html = await res.text();
    expect(html).toMatch(/export|download/i);
    expect(html).not.toMatch(/href="\/internal/);
  });

  test("debug route blocked without token", async ({ request }) => {
    const res = await request.get("/internal/entitlements", { maxRedirects: 0 });
    expect(res.status()).toBe(404);
  });

  test("archive page loads export affordances", async ({ request }) => {
    const res = await request.get("/archive");
    expect(res.ok()).toBeTruthy();
    const html = await res.text();
    expect(html).toMatch(/archive|export|reflection/i);
    expect(html).not.toMatch(/href="\/internal/);
  });

  test("journal HTML has no debug nav links", async ({ request }) => {
    const res = await request.get("/journal");
    const html = await res.text();
    expect(html).not.toMatch(/href="\/internal/);
    expect(html).toContain('href="/account"');
  });
});
