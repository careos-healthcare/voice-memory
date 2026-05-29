import { expect, type Locator, type Page } from "@playwright/test";

export const MOBILE_VIEWPORT = { width: 375, height: 667 } as const;

export async function assertNoHorizontalOverflow(page: Page): Promise<void> {
  const overflow = await page.evaluate(() => {
    const doc = document.documentElement;
    return doc.scrollWidth > doc.clientWidth + 8;
  });
  expect(overflow, "page should not scroll horizontally at 375px").toBe(false);
}

export async function assertNavUsable(page: Page): Promise<void> {
  const nav = page.getByRole("navigation", { name: "Primary" });
  await expect(nav).toBeVisible();
  const journal = nav.getByRole("link", { name: "Journal" });
  await expect(journal).toBeVisible();
  const box = await journal.boundingBox();
  expect(box?.width ?? 0).toBeGreaterThan(0);
  expect(box?.height ?? 0).toBeGreaterThanOrEqual(40);
}

export async function assertMinTapTarget(locator: Locator, minPx = 44): Promise<void> {
  await expect(locator.first()).toBeVisible();
  const box = await locator.first().boundingBox();
  expect(box?.height ?? 0).toBeGreaterThanOrEqual(minPx - 4);
  expect(box?.width ?? 0).toBeGreaterThanOrEqual(minPx - 4);
}

export async function assertCriticalTextVisible(page: Page, pattern: RegExp): Promise<void> {
  await expect(page.getByText(pattern).first()).toBeVisible();
}
