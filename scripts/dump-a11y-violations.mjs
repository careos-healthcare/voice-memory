#!/usr/bin/env node
import { chromium } from "playwright";
import AxeBuilder from "@axe-core/playwright";

const routes = ["/export", "/settings", "/search", "/weekly", "/insights"];
const base = process.env.BASE_URL ?? "http://127.0.0.1:3113";

const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 375, height: 667 } });
const page = await context.newPage();
for (const path of routes) {
  await page.goto(base + path);
  await page.waitForLoadState("domcontentloaded");
  const contrast = await new AxeBuilder({ page }).withRules(["color-contrast"]).analyze();
  const v = contrast.violations.find((x) => x.id === "color-contrast");
  console.log("\n##", path);
  if (!v) {
    console.log("  (none)");
    continue;
  }
  for (const n of v.nodes.slice(0, 5)) {
    console.log(" -", n.html?.slice(0, 120));
    console.log("   ", n.any?.[0]?.message ?? n.failureSummary?.slice(0, 120));
  }
}
await browser.close();
