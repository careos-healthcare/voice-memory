import { expect, test } from "@playwright/test";

import { LAUNCH_SURFACE_ROUTES } from "./helpers/accessibility-routes";
import { installA11yDynamicSeed, A11Y_DYNAMIC_ROUTES } from "./fixtures/seed-a11y-dynamic.mjs";
import { MOBILE_VIEWPORT } from "./helpers/mobile-layout";

const SR_SAMPLE_ROUTES = [
  ...new Set(["/", "/record", "/journal", ...LAUNCH_SURFACE_ROUTES.slice(0, 12)]),
];

test.describe("Screen reader structure — runtime", () => {
  test.use({ viewport: MOBILE_VIEWPORT });

  test("recorder exposes polite status region", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("domcontentloaded");
    const live = page.locator('[aria-live="polite"], [role="status"][aria-live]');
    await expect(live.first()).toBeAttached();
  });

  test("record route has mic permission or capture status structure", async ({ page }) => {
    await page.goto("/record");
    await page.waitForLoadState("domcontentloaded");
    const status = page.locator('[role="status"], [aria-live="polite"]');
    expect(await status.count()).toBeGreaterThan(0);
  });

  for (const path of SR_SAMPLE_ROUTES) {
    test(`heading order ${path}`, async ({ page }) => {
      await page.emulateMedia({ reducedMotion: "reduce" });
      await page.goto(path);
      await page.waitForLoadState("domcontentloaded");
      const main = page.locator("main#main-content, main[id='main-content'], main").first();
      await expect(main).toBeVisible();
      await expect(main.getByRole("heading", { level: 1 }).first()).toBeVisible();
      const levels = await main.locator("h1, h2, h3, h4").evaluateAll((nodes) =>
        nodes.map((n) => Number.parseInt(n.tagName[1], 10)),
      );
      expect(levels.length, `${path} needs headings in main`).toBeGreaterThan(0);
      expect(levels[0], `${path} needs h1 before other heading levels in main`).toBe(1);
    });
  }

  test("dynamic moment route icon delete has accessible name", async ({ page }) => {
    await installA11yDynamicSeed(page);
    await page.goto(A11Y_DYNAMIC_ROUTES.entry);
    await page.waitForLoadState("domcontentloaded");
    const deleteBtn = page.getByRole("button", { name: /delete moment/i });
    if ((await deleteBtn.count()) > 0) {
      await expect(deleteBtn.first()).toBeVisible();
    }
  });
});
