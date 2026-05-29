import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

import {
  analyzeRouteA11y,
  assertZeroSeriousViolations,
  formatViolationSummary,
} from "./helpers/a11y-axe";

/** Primary launch routes — zero serious/critical axe violations required. */
const PRIMARY_ROUTES = [
  "/",
  "/record",
  "/journal",
  "/memory",
  "/threads",
  "/archive",
  "/pricing",
  "/account",
  "/export",
  "/settings",
  "/search",
  "/weekly",
  "/insights",
  "/monthly",
  "/privacy",
  "/terms",
  "/contact",
  "/offline",
  "/welcome",
  "/reminders",
] as const;

/** Secondary — must pass or be documented as not launch-ready. */
const SECONDARY_ROUTES = ["/safety"] as const;

async function assertPageLandmarks(page: import("@playwright/test").Page, path: string) {
  const h1 = await page.locator("h1").count();
  expect(h1, `${path} needs exactly one h1`).toBeGreaterThanOrEqual(1);

  const main = page.locator("main#main-content, main[id='main-content'], main");
  await expect(main.first(), `${path} needs a main landmark`).toBeVisible();

  const buttons = await page.getByRole("button").all();
  let unlabeledIconButtons = 0;
  for (const button of buttons) {
    const hasSvg = (await button.locator("svg").count()) > 0;
    if (!hasSvg) continue;
    const aria = (await button.getAttribute("aria-label"))?.trim();
    const text = (await button.innerText()).replace(/\s+/g, " ").trim();
    if (!aria && !text) unlabeledIconButtons += 1;
  }
  expect(
    unlabeledIconButtons,
    `${path} has icon-only buttons without accessible names`,
  ).toBe(0);
}

test.describe("Accessibility — strict WCAG gate", () => {
  test.use({
    viewport: { width: 375, height: 667 },
    isMobile: true,
    hasTouch: true,
  });

  for (const path of PRIMARY_ROUTES) {
    test(`primary ${path} — axe + landmarks`, async ({ page }) => {
      await page.emulateMedia({ reducedMotion: "reduce" });
      await page.goto(path);
      await page.waitForLoadState("domcontentloaded");
      const heading = page.getByRole("heading", { level: 1 }).first();
      await expect(heading).toBeVisible();
      await page.waitForFunction(
        () => {
          const el = document.querySelector("h1");
          if (!el) return false;
          const style = getComputedStyle(el);
          const opacity = Number.parseFloat(style.opacity);
          const rgb = style.color.match(/\d+/g);
          if (!rgb || rgb.length < 3) return false;
          const [r, g, b] = rgb.map(Number);
          return opacity >= 0.95 && r + g + b > 120;
        },
        undefined,
        { timeout: 10_000 },
      );

      await assertPageLandmarks(page, path);

      const { blocking, contrastSerious } = await analyzeRouteA11y(page);
      assertZeroSeriousViolations(path, blocking, contrastSerious);

      if (blocking.length + contrastSerious.length > 0) {
        throw new Error(formatViolationSummary(path, blocking, contrastSerious));
      }
    });
  }

  for (const path of SECONDARY_ROUTES) {
    test(`secondary ${path} — axe`, async ({ page }) => {
      await page.emulateMedia({ reducedMotion: "reduce" });
      await page.goto(path);
      await page.waitForLoadState("domcontentloaded");
      const { blocking, contrastSerious } = await analyzeRouteA11y(page);
      assertZeroSeriousViolations(path, blocking, contrastSerious);
    });
  }

  test("record route exposes labeled record control", async ({ page }) => {
    await page.goto("/record");
    await page.waitForLoadState("domcontentloaded");
    const recordControl = page.locator('[data-primary-cta="recorder"], [data-primary-cta="retry"]');
    await expect(recordControl.first()).toBeVisible();
    const label =
      (await recordControl.first().getAttribute("aria-label")) ??
      (await recordControl.first().innerText());
    expect(label?.trim().length ?? 0).toBeGreaterThan(0);
  });

  test("no serious violations with prefers-reduced-motion", async ({ page }) => {
    await page.emulateMedia({ reducedMotion: "reduce" });
    await page.goto("/");
    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
      .analyze();
    const serious = results.violations.filter((v) =>
      ["serious", "critical"].includes(v.impact ?? ""),
    );
    expect(serious, serious.map((v) => v.id).join(", ")).toEqual([]);
  });
});
