import { expect, test, type Page } from "@playwright/test";

import {
  TIER_B_ROUTES,
  TIER_C_ROUTES,
} from "./helpers/accessibility-routes";
import {
  assertCriticalTextVisible,
  assertMinTapTarget,
  assertNavUsable,
  assertNoHorizontalOverflow,
  MOBILE_VIEWPORT,
} from "./helpers/mobile-layout";

const PRIMARY_ROUTES: Array<{
  path: string;
  name: string;
  primaryCta: (page: Page) => import("@playwright/test").Locator;
  critical?: RegExp;
  skipNav?: boolean;
}> = [
  {
    path: "/",
    name: "home",
    skipNav: true,
    primaryCta: (page) =>
      page.locator("#recorder [data-primary-cta='recorder'], #recorder button").first(),
    critical: /record|reflection|ArchiveMe/i,
  },
  {
    path: "/record",
    name: "record",
    skipNav: true,
    primaryCta: (page) =>
      page.locator("[data-primary-cta='recorder'], button").filter({ hasText: /record/i }).first(),
    critical: /Voice capture|capture/i,
  },
  {
    path: "/journal",
    name: "journal",
    primaryCta: (page) => page.getByRole("link", { name: "Record" }),
    critical: /Journal/i,
  },
  {
    path: "/memory",
    name: "memory",
    primaryCta: (page) => page.getByRole("link", { name: "Journal" }),
    critical: /memory|return|reflection/i,
  },
  {
    path: "/threads",
    name: "threads",
    primaryCta: (page) => page.getByRole("navigation", { name: "Primary" }),
    critical: /Worth returning|thread/i,
  },
  {
    path: "/archive",
    name: "archive",
    primaryCta: (page) => page.getByRole("link", { name: "Record" }).or(page.getByRole("button", { name: /export/i })),
    critical: /Archive/i,
  },
  {
    path: "/pricing",
    name: "pricing",
    primaryCta: (page) => page.locator("[data-pricing-plan='pro'], [data-pricing-ssr]").first(),
    critical: /Plans for your voice archive/i,
  },
  {
    path: "/account",
    name: "account",
    primaryCta: (page) => page.getByRole("navigation", { name: "Primary" }),
    critical: /account|sign in|sync/i,
  },
  {
    path: "/export",
    name: "export",
    primaryCta: (page) =>
      page.getByRole("button", { name: /export|json|print/i }).first(),
    critical: /export/i,
  },
  {
    path: "/reminders",
    name: "reminders",
    primaryCta: (page) => page.getByRole("link", { name: "View homepage" }),
    critical: /Reminders/i,
  },
];

test.describe("Mobile 375px primary routes", () => {
  test.use({ viewport: MOBILE_VIEWPORT });

  for (const route of PRIMARY_ROUTES) {
    test(`${route.name} @ ${route.path} — layout and CTA`, async ({ page }) => {
      await page.goto(route.path, { waitUntil: "networkidle" });

      await assertNoHorizontalOverflow(page);

      if (!route.skipNav) {
        await assertNavUsable(page);
      }

      if (route.critical) {
        await assertCriticalTextVisible(page, route.critical);
      }

      const cta = route.primaryCta(page);
      if ((await cta.count()) > 0) {
        await assertMinTapTarget(cta, 40);
      }
    });
  }
});

test.describe("Mobile 375px launch surface overflow", () => {
  test.use({ viewport: MOBILE_VIEWPORT });

  for (const path of [...TIER_B_ROUTES, ...TIER_C_ROUTES]) {
    test(`${path} — no horizontal overflow`, async ({ page }) => {
      await page.goto(path, { waitUntil: "networkidle" });
      await assertNoHorizontalOverflow(page);
    });
  }
});

test("pricing SSR plans visible before hydration", async ({ page }) => {
  await page.goto("/pricing", { waitUntil: "networkidle" });
  const shell = page.locator("[data-pricing-ssr]");
  await expect(shell).toBeVisible({ timeout: 15_000 });
  await expect(page.locator("[data-pricing-plan='free']")).toContainText("Free");
  await expect(page.locator("[data-pricing-plan='pro']")).toContainText("Pro");
  await expect(page.locator("[data-billing-state]")).toHaveAttribute(
    "data-billing-state",
    /configured|disabled/,
  );
});
