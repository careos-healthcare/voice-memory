import { expect, test } from "@playwright/test";

const DEVICE_ID = crypto.randomUUID();

test.describe("Hostile user — API abuse", () => {
  test("rejects unauthenticated analyze and atmosphere", async ({ request }) => {
    expect((await request.post("/api/analyze", { data: { transcript: "x" } })).status()).toBe(
      401,
    );
    expect((await request.post("/api/atmosphere", { data: { prompt: "x" } })).status()).toBe(
      401,
    );
  });

  test("rejects invalid capture token on transcribe", async ({ request }) => {
    const res = await request.post("/api/transcribe", {
      headers: { "x-vm-capture-token": "not-a-valid-token" },
      multipart: {
        audio: {
          name: "empty.webm",
          mimeType: "audio/webm",
          buffer: Buffer.alloc(8),
        },
      },
    });
    expect([401, 403]).toContain(res.status());
  });

  test("rejects replayed or mismatched capture binding", async ({ request }) => {
    const attest = await request.post("/api/capture/attest", {
      data: { deviceId: DEVICE_ID },
      headers: { "x-voicememory-test-ip": `hostile-proof-${crypto.randomUUID()}` },
    });
    expect(attest.ok()).toBeTruthy();
    const { token } = (await attest.json()) as { token: string };
    const replay = await request.post("/api/transcribe", {
      headers: {
        "x-vm-capture-token": token,
        "x-forwarded-for": "203.0.113.99",
      },
      multipart: {
        audio: {
          name: "tiny.webm",
          mimeType: "audio/webm",
          buffer: Buffer.alloc(16),
        },
      },
    });
    expect([401, 403, 400, 413, 422]).toContain(replay.status());
  });

  test("webhook rejects missing signature", async ({ request }) => {
    const res = await request.post("/api/billing/webhook", {
      data: "{}",
      headers: { "content-type": "application/json" },
    });
    expect([400, 401, 403, 503]).toContain(res.status());
  });

  test("account delete route requires auth", async ({ request }) => {
    const res = await request.post("/api/account/delete", { data: {} });
    expect([401, 403, 503]).toContain(res.status());
  });

  test("journal API requires auth", async ({ request }) => {
    const res = await request.get("/api/journal");
    expect([401, 403, 503]).toContain(res.status());
  });

  test("oversized analyze payload rejected or auth first", async ({ request }) => {
    const huge = "word ".repeat(50_000);
    const res = await request.post("/api/analyze", {
      data: { transcript: huge },
    });
    expect([401, 413, 400, 503]).toContain(res.status());
  });

  test("internal HTML never returns founder dashboard without token", async ({
    request,
  }) => {
    const res = await request.get("/internal/behavior-truth", { maxRedirects: 0 });
    expect(res.status()).toBe(404);
    const html = await res.text();
    expect(html).not.toMatch(/Founder review|Behavior truth panel/i);
  });
});
