import { expect } from "@playwright/test";
import type { Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

export type AxeViolationSummary = {
  id: string;
  impact: string;
  help: string;
  nodes: number;
};

export async function analyzeRouteA11y(page: Page): Promise<{
  blocking: AxeViolationSummary[];
  contrastSerious: AxeViolationSummary[];
}> {
  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
    .analyze();

  const contrastOnly = await new AxeBuilder({ page })
    .withRules(["color-contrast"])
    .analyze();

  const blocking = results.violations
    .filter((v) => ["serious", "critical"].includes(v.impact ?? ""))
    .filter((v) => v.id !== "color-contrast")
    .map((v) => ({
      id: v.id,
      impact: v.impact ?? "unknown",
      help: v.help,
      nodes: v.nodes.length,
    }));

  const contrastSerious = contrastOnly.violations
    .filter(
      (v) =>
        v.id === "color-contrast" &&
        (v.impact === "serious" || v.impact === "critical"),
    )
    .map((v) => ({
      id: v.id,
      impact: v.impact ?? "unknown",
      help: v.help,
      nodes: v.nodes.length,
    }));

  return { blocking, contrastSerious };
}

export function formatViolationSummary(
  route: string,
  blocking: AxeViolationSummary[],
  contrastSerious: AxeViolationSummary[],
): string {
  const lines = [`Route ${route}:`];
  for (const v of [...blocking, ...contrastSerious]) {
    lines.push(`  ${v.id} (${v.impact}): ${v.help} — ${v.nodes} nodes`);
  }
  return lines.join("\n");
}

export function assertZeroSeriousViolations(
  route: string,
  blocking: AxeViolationSummary[],
  contrastSerious: AxeViolationSummary[],
): void {
  if (blocking.length > 0 || contrastSerious.length > 0) {
    expect(
      { blocking, contrastSerious },
      formatViolationSummary(route, blocking, contrastSerious),
    ).toEqual({ blocking: [], contrastSerious: [] });
  }
}
