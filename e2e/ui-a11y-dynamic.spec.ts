import { expect, test } from "@playwright/test";

import {
  analyzeRouteA11y,
  assertZeroSeriousViolations,
  formatViolationSummary,
} from "./helpers/a11y-axe";
import { assertPageLandmarks, preparePageForA11y } from "./helpers/a11y-page-ready";
import { assertNoHorizontalOverflow, MOBILE_VIEWPORT } from "./helpers/mobile-layout";
import {
  A11Y_DYNAMIC_ROUTES,
  installA11yDynamicSeed,
} from "./fixtures/seed-a11y-dynamic.mjs";

const DYNAMIC_AXE_ROUTES = [
  A11Y_DYNAMIC_ROUTES.entry,
  A11Y_DYNAMIC_ROUTES.thread,
  A11Y_DYNAMIC_ROUTES.territory,
  A11Y_DYNAMIC_ROUTES.roundupWeek,
  A11Y_DYNAMIC_ROUTES.roundupMonth,
  A11Y_DYNAMIC_ROUTES.roundupWeekAlias,
];

const DYNAMIC_NOT_FOUND_ROUTES = [
  A11Y_DYNAMIC_ROUTES.entryMissing,
  A11Y_DYNAMIC_ROUTES.threadMissing,
  A11Y_DYNAMIC_ROUTES.territoryMissing,
];

test.describe("Accessibility — dynamic routes (seeded)", () => {
  test.use({
    viewport: MOBILE_VIEWPORT,
    isMobile: true,
    hasTouch: true,
  });

  test.beforeEach(async ({ page }) => {
    await installA11yDynamicSeed(page);
  });

  for (const path of DYNAMIC_AXE_ROUTES) {
    test(`dynamic ${path} — axe + landmarks + overflow`, async ({ page }) => {
      await preparePageForA11y(page, path);
      await assertPageLandmarks(page, path);
      await assertNoHorizontalOverflow(page);
      const { blocking, contrastSerious } = await analyzeRouteA11y(page);
      assertZeroSeriousViolations(path, blocking, contrastSerious);
      if (blocking.length + contrastSerious.length > 0) {
        throw new Error(formatViolationSummary(path, blocking, contrastSerious));
      }
    });
  }

  for (const path of DYNAMIC_NOT_FOUND_ROUTES) {
    test(`dynamic not-found ${path}`, async ({ page }) => {
      await page.emulateMedia({ reducedMotion: "reduce" });
      await page.goto(path);
      await page.waitForLoadState("domcontentloaded");
      await expect(page.getByRole("heading", { level: 1 }).first()).toBeVisible({
        timeout: 15_000,
      });
      await assertPageLandmarks(page, path);
      await assertNoHorizontalOverflow(page);
      const { blocking, contrastSerious } = await analyzeRouteA11y(page);
      assertZeroSeriousViolations(path, blocking, contrastSerious);
    });
  }
});
