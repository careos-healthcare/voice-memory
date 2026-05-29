import { expect, test } from "@playwright/test";

import {
  analyzeRouteA11y,
  assertZeroSeriousViolations,
  formatViolationSummary,
} from "./helpers/a11y-axe";
import { assertPageLandmarks, preparePageForA11y } from "./helpers/a11y-page-ready";
import {
  LAUNCH_SURFACE_ROUTES,
  TIER_D_LOCKED_SAMPLES,
} from "./helpers/accessibility-routes";

test.describe("Accessibility — full launch surface", () => {
  test.use({
    viewport: { width: 375, height: 667 },
    isMobile: true,
    hasTouch: true,
  });

  for (const path of LAUNCH_SURFACE_ROUTES) {
    test(`launch surface ${path}`, async ({ page }) => {
      await preparePageForA11y(page, path);
      await assertPageLandmarks(page, path);
      const { blocking, contrastSerious } = await analyzeRouteA11y(page);
      assertZeroSeriousViolations(path, blocking, contrastSerious);
      if (blocking.length + contrastSerious.length > 0) {
        throw new Error(formatViolationSummary(path, blocking, contrastSerious));
      }
    });
  }

  for (const path of TIER_D_LOCKED_SAMPLES) {
    test(`locked ${path} returns 404 without sensitive body`, async ({ request }) => {
      const res = await request.get(path, { maxRedirects: 0 });
      expect(res.status()).toBe(404);
      const body = await res.text();
      expect(body.length).toBeLessThan(8000);
      expect(body).not.toMatch(/Instrumentation|node:util\/types|sk_live|DEBUG_ACCESS_TOKEN/i);
    });
  }
});
