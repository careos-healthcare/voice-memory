import { expect, test } from "@playwright/test";

import {
  analyzeRouteA11y,
  assertZeroSeriousViolations,
  formatViolationSummary,
} from "./helpers/a11y-axe";
import { assertPageLandmarks, preparePageForA11y } from "./helpers/a11y-page-ready";
import { assertNoHorizontalOverflow, MOBILE_VIEWPORT } from "./helpers/mobile-layout";
import {
  A11Y_PERMUTATIONS,
  installA11yPermutation,
} from "./fixtures/seed-a11y-permutations.mjs";

test.describe("Accessibility — dynamic content permutations", () => {
  test.use({
    viewport: MOBILE_VIEWPORT,
    isMobile: true,
    hasTouch: true,
  });

  for (const perm of A11Y_PERMUTATIONS) {
    for (const path of perm.testPaths) {
      test(`perm ${perm.id} @ ${path}`, async ({ page }) => {
        await installA11yPermutation(page, perm);
        await preparePageForA11y(page, path);
        await assertPageLandmarks(page, path);
        await assertNoHorizontalOverflow(page);
        const { blocking, contrastSerious } = await analyzeRouteA11y(page);
        assertZeroSeriousViolations(path, blocking, contrastSerious);
        if (blocking.length + contrastSerious.length > 0) {
          throw new Error(formatViolationSummary(path, blocking, contrastSerious));
        }
        const crashed = await page.locator("text=Application error").count();
        expect(crashed, `${path} crashed`).toBe(0);
      });
    }
  }
});
