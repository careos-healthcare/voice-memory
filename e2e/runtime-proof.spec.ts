import { expect, test } from "@playwright/test";

const DEVICE_ID = crypto.randomUUID();

test.describe("Runtime proof — HTTP surface", () => {
  test("health returns checks without secrets", async ({ request }) => {
    const res = await request.get("/api/health");
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.checks).toBeTruthy();
    expect(JSON.stringify(body)).not.toMatch(/sk_live|sk_test|whsec_|DEBUG_ACCESS_TOKEN/i);
  });

  test("internal route blocked without token", async ({ request }) => {
    const res = await request.get("/internal/founder-review", { maxRedirects: 0 });
    expect(res.status()).toBe(404);
  });

  test("retired debug route blocked", async ({ request }) => {
    const res = await request.get("/debug/founder-review", { maxRedirects: 0 });
    expect(res.status()).toBe(404);
  });

  test("unauthenticated transcribe rejected", async ({ request }) => {
    const res = await request.post("/api/transcribe", {
      multipart: {
        audio: {
          name: "empty.webm",
          mimeType: "audio/webm",
          buffer: Buffer.alloc(0),
        },
      },
    });
    expect(res.status()).toBe(401);
  });

  test("billing checkout fail-closed without session", async ({ request }) => {
    const res = await request.post("/api/billing/checkout");
    expect([401, 503]).toContain(res.status());
  });

  test("metrics resurfacing forbidden without auth", async ({ request }) => {
    const res = await request.get("/api/metrics/resurfacing");
    expect([401, 403]).toContain(res.status());
  });

  test("export page has no debug token in HTML", async ({ request }) => {
    const res = await request.get("/export");
    expect(res.ok()).toBeTruthy();
    const html = await res.text();
    expect(html).not.toContain("debug_token=");
  });

  test("capture attest issues token", async ({ request }) => {
    const attest = await request.post("/api/capture/attest", {
      data: { deviceId: DEVICE_ID },
      headers: { "x-voicememory-test-ip": `runtime-proof-${crypto.randomUUID()}` },
    });
    expect(attest.ok()).toBeTruthy();
    const { token } = (await attest.json()) as { token: string };
    expect(token.length).toBeGreaterThan(10);
  });
});
