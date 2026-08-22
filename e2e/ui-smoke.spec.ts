import { expect, test } from "@playwright/test";

import { WEB_MARKETING_PROMISE } from "../packages/shared/lib/site/web-marketing-copy";

/** UI smoke — marketing web only; consumer product lives in mobile. */
test.describe("UI smoke", () => {
  test("homepage is focused marketing without recorder", async ({ request }) => {
    const res = await request.get("/");
    expect(res.ok()).toBeTruthy();
    const html = await res.text();
    expect(html).toContain("ArchiveMe");
    expect(html).toContain(WEB_MARKETING_PROMISE);
    expect(html).toContain("Beta");
    expect(html).not.toContain('id="recorder"');
    expect(html).not.toMatch(/href="\/internal/);
    expect(html).not.toMatch(/href="\/journal/);
    expect(html).not.toMatch(/href="\/archive-belief/);
  });

  test("retired consumer routes return gone", async ({ request }) => {
    for (const path of ["/record", "/journal", "/weekly", "/archive", "/theories", "/pricing"]) {
      const res = await request.get(path);
      expect(res.status(), path).toBe(410);
    }
  });

  test("legal and support routes remain available", async ({ request }) => {
    for (const path of ["/privacy", "/terms", "/contact", "/safety", "/beta", "/welcome"]) {
      const res = await request.get(path);
      expect(res.ok(), path).toBeTruthy();
    }
  });

  test("privacy-simple redirects to privacy", async ({ request }) => {
    const res = await request.get("/privacy-simple", { maxRedirects: 0 });
    expect(res.status()).toBe(308);
    expect(res.headers().location).toMatch(/\/privacy$/);
  });

  test("internal route blocked without token", async ({ request }) => {
    const res = await request.get("/internal/entitlements", { maxRedirects: 0 });
    expect(res.status()).toBe(404);
  });
});
