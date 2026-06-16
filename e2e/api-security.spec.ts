import { test, expect } from "@playwright/test";

const DEVICE_ID = crypto.randomUUID();

test.describe("API security", () => {
  test("GET transcribe returns JSON route info", async ({ request }) => {
    const res = await request.get("/api/transcribe");
    expect(res.status()).toBe(405);
    expect(res.headers()["content-type"]).toContain("application/json");
    const body = await res.json();
    expect(body.route).toBe("/api/transcribe");
    expect(body.code).toBe("METHOD_NOT_ALLOWED");
  });

  test("rejects unauthenticated transcribe", async ({ request }) => {
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
    const body = await res.json();
    expect(body.code).toBe("missing_capture_token");
  });

  test("rejects unauthenticated analyze", async ({ request }) => {
    const res = await request.post("/api/analyze", {
      data: { transcript: "hello" },
    });
    expect(res.status()).toBe(401);
    const body = await res.json();
    expect(body.code).toBe("missing_capture_token");
  });

  test("rejects unauthenticated atmosphere", async ({ request }) => {
    const res = await request.post("/api/atmosphere", {
      data: { prompt: "soft blue gradient" },
    });
    expect(res.status()).toBe(401);
  });

  test("device attest then transcribe requires audio", async ({ request }) => {
    const attest = await request.post("/api/capture/attest", {
      data: { deviceId: DEVICE_ID },
    });
    expect(attest.ok()).toBeTruthy();
    const { token } = (await attest.json()) as { token: string };
    const res = await request.post("/api/transcribe", {
      headers: { "x-vm-capture-token": token },
      multipart: {
        audio: {
          name: "empty.webm",
          mimeType: "audio/webm",
          buffer: Buffer.alloc(0),
        },
      },
    });
    expect(res.status()).not.toBe(401);
  });

  test("billing checkout fails closed without Stripe env", async ({ request }) => {
    const res = await request.post("/api/billing/checkout");
    expect([401, 503]).toContain(res.status());
  });
});
