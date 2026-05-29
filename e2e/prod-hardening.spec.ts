import { test, expect } from "@playwright/test";

const DEVICE_ID = "550e8400-e29b-41d4-a716-446655440000";

test.describe("Production hardening", () => {
  test("health endpoint returns checks without secrets", async ({ request }) => {
    const res = await request.get("/api/health");
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.checks).toBeTruthy();
    expect(JSON.stringify(body)).not.toMatch(/sk_live|sk_test|whsec_/);
  });

  test("metrics aggregate forbidden without founder session", async ({ request }) => {
    const res = await request.get("/api/metrics/resurfacing");
    expect([401, 403]).toContain(res.status());
  });

  test("account page includes deletion confirmation copy", async ({ request }) => {
    const res = await request.get("/account");
    expect(res.ok()).toBeTruthy();
    const html = await res.text();
    expect(html.toLowerCase()).toMatch(/delete/);
  });

  test("pricing page loads without payment-complete claim", async ({ request }) => {
    const res = await request.get("/pricing");
    expect(res.ok()).toBeTruthy();
    const html = (await res.text()).toLowerCase();
    expect(html).not.toContain("payment complete");
  });

  test("export page has no debug token in HTML", async ({ request }) => {
    const res = await request.get("/export");
    expect(res.ok()).toBeTruthy();
    const html = await res.text();
    expect(html).not.toContain("debug_token=");
  });

  test("device attest still works", async ({ request }) => {
    const attest = await request.post("/api/capture/attest", {
      data: { deviceId: DEVICE_ID },
    });
    expect(attest.ok()).toBeTruthy();
  });
});
