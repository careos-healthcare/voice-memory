import { expect, type Page } from "@playwright/test";

export async function preparePageForA11y(page: Page, path: string): Promise<void> {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto(path);
  await page.waitForLoadState("domcontentloaded");
  const heading = page.getByRole("heading", { level: 1 }).first();
  await expect(heading, `${path} needs visible h1`).toBeVisible({ timeout: 15_000 });
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
}

export async function assertPageLandmarks(page: Page, path: string): Promise<void> {
  const h1 = await page.locator("h1").count();
  expect(h1, `${path} needs at least one h1`).toBeGreaterThanOrEqual(1);

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
