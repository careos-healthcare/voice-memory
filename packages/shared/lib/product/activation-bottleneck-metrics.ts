import { countCompletedReflections } from "@/lib/mobile/install-prompt-gate";
import { hasLocalEvent, readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";

export const ACTIVATION_BOTTLENECK_EVENTS = {
  previewShown: "activation_theory_preview_shown",
  previewClicked: "activation_theory_preview_clicked",
  reflection4Reached: "activation_reflection_4_reached",
  reflection5Reached: "activation_reflection_5_reached",
  simulatorShown: "simulator_shown",
  simulatorExampleOpened: "simulator_example_opened",
  simulatorCtaClicked: "simulator_cta_clicked",
} as const;

export interface ActivationBottleneckMetricsReport {
  generatedAt: string;
  totalReached4: number;
  totalReached5: number;
  reflection4To5ConversionRate: number | null;
  previewShownCount: number;
  previewClickCount: number;
  simulatorShownCount: number;
  simulatorExampleOpenedCount: number;
  simulatorCtaClickedCount: number;
  conversionWithSimulatorRate: number | null;
  conversionWithoutSimulatorRate: number | null;
  reached4WithSimulatorShown: number;
  reached4WithoutSimulatorShown: number;
  reached5AfterSimulatorShown: number;
  reached5WithoutSimulatorShown: number;
  currentReflectionCount: number;
  lines: string[];
}

function countNamed(name: string): number {
  return readLocalEvents().filter((e) => e.name === name).length;
}

function firstEventAt(name: string): string | undefined {
  const matches = readLocalEvents()
    .filter((e) => e.name === name)
    .sort((a, b) => a.at.localeCompare(b.at));
  return matches[0]?.at;
}

function pct(numerator: number, denominator: number): number | null {
  if (denominator <= 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

function buildSimulatorConversionCohorts(): {
  reached4WithSimulatorShown: number;
  reached4WithoutSimulatorShown: number;
  reached5AfterSimulatorShown: number;
  reached5WithoutSimulatorShown: number;
  conversionWithSimulatorRate: number | null;
  conversionWithoutSimulatorRate: number | null;
} {
  const reached4At = firstEventAt(ACTIVATION_BOTTLENECK_EVENTS.reflection4Reached);
  const reached5At = firstEventAt(ACTIVATION_BOTTLENECK_EVENTS.reflection5Reached);
  const simulatorShownAt = firstEventAt(ACTIVATION_BOTTLENECK_EVENTS.simulatorShown);

  const reached4 = reached4At ? 1 : 0;
  const reached5 = reached5At ? 1 : 0;

  if (reached4 === 0) {
    return {
      reached4WithSimulatorShown: 0,
      reached4WithoutSimulatorShown: 0,
      reached5AfterSimulatorShown: 0,
      reached5WithoutSimulatorShown: 0,
      conversionWithSimulatorRate: null,
      conversionWithoutSimulatorRate: null,
    };
  }

  const sawSimulatorBefore5 =
    Boolean(simulatorShownAt && reached5At && simulatorShownAt <= reached5At) ||
    Boolean(simulatorShownAt && !reached5At);

  const withSimulator = sawSimulatorBefore5 && simulatorShownAt ? 1 : 0;
  const withoutSimulator = reached4 - withSimulator;
  const reached5With = reached5 && withSimulator ? 1 : 0;
  const reached5Without = reached5 && !withSimulator ? 1 : 0;

  return {
    reached4WithSimulatorShown: withSimulator,
    reached4WithoutSimulatorShown: withoutSimulator,
    reached5AfterSimulatorShown: reached5With,
    reached5WithoutSimulatorShown: reached5Without,
    conversionWithSimulatorRate: pct(reached5With, withSimulator),
    conversionWithoutSimulatorRate: pct(reached5Without, withoutSimulator),
  };
}

/** Record 4- and 5-reflection milestones once per device. */
export function observeActivationBottleneckMilestones(reflectionCount?: number): void {
  const count = reflectionCount ?? countCompletedReflections();
  if (count >= 4 && !hasLocalEvent(ACTIVATION_BOTTLENECK_EVENTS.reflection4Reached)) {
    trackLocalEvent(ACTIVATION_BOTTLENECK_EVENTS.reflection4Reached, {
      reflectionCount: String(count),
    });
  }
  if (count >= 5 && !hasLocalEvent(ACTIVATION_BOTTLENECK_EVENTS.reflection5Reached)) {
    trackLocalEvent(ACTIVATION_BOTTLENECK_EVENTS.reflection5Reached, {
      reflectionCount: String(count),
    });
  }
}

export function trackActivationTheoryPreviewShown(reflectionCount: number): void {
  trackLocalEvent(ACTIVATION_BOTTLENECK_EVENTS.previewShown, {
    reflectionCount: String(reflectionCount),
  });
}

export function trackActivationTheoryPreviewClicked(reflectionCount: number): void {
  trackLocalEvent(ACTIVATION_BOTTLENECK_EVENTS.previewClicked, {
    reflectionCount: String(reflectionCount),
  });
}

export function trackFirstBlindSpotSimulatorShown(reflectionCount: number): void {
  trackLocalEvent(ACTIVATION_BOTTLENECK_EVENTS.simulatorShown, {
    reflectionCount: String(reflectionCount),
  });
}

export function trackFirstBlindSpotSimulatorExampleOpened(reflectionCount: number): void {
  trackLocalEvent(ACTIVATION_BOTTLENECK_EVENTS.simulatorExampleOpened, {
    reflectionCount: String(reflectionCount),
  });
}

export function trackFirstBlindSpotSimulatorCtaClicked(reflectionCount: number): void {
  trackLocalEvent(ACTIVATION_BOTTLENECK_EVENTS.simulatorCtaClicked, {
    reflectionCount: String(reflectionCount),
  });
}

export function buildActivationBottleneckMetricsReport(): ActivationBottleneckMetricsReport {
  const totalReached4 = Math.max(
    countNamed(ACTIVATION_BOTTLENECK_EVENTS.reflection4Reached),
    countCompletedReflections() >= 4 ? 1 : 0,
  );
  const totalReached5 = Math.max(
    countNamed(ACTIVATION_BOTTLENECK_EVENTS.reflection5Reached),
    countCompletedReflections() >= 5 ? 1 : 0,
  );
  const previewShownCount = countNamed(ACTIVATION_BOTTLENECK_EVENTS.previewShown);
  const previewClickCount = countNamed(ACTIVATION_BOTTLENECK_EVENTS.previewClicked);
  const simulatorShownCount = countNamed(ACTIVATION_BOTTLENECK_EVENTS.simulatorShown);
  const simulatorExampleOpenedCount = countNamed(
    ACTIVATION_BOTTLENECK_EVENTS.simulatorExampleOpened,
  );
  const simulatorCtaClickedCount = countNamed(ACTIVATION_BOTTLENECK_EVENTS.simulatorCtaClicked);
  const cohorts = buildSimulatorConversionCohorts();

  const reflection4To5ConversionRate =
    totalReached4 > 0
      ? Math.round((totalReached5 / totalReached4) * 1000) / 10
      : null;

  const lines = [
    `Reached 4 reflections: ${totalReached4}`,
    `Reached 5 reflections: ${totalReached5}`,
    `4→5 conversion: ${reflection4To5ConversionRate ?? "—"}%`,
    `Theory preview shown: ${previewShownCount}`,
    `Theory preview clicked: ${previewClickCount}`,
    `Simulator shown: ${simulatorShownCount}`,
    `Simulator example opened: ${simulatorExampleOpenedCount}`,
    `Simulator CTA clicked: ${simulatorCtaClickedCount}`,
    `4→5 with simulator shown: ${cohorts.conversionWithSimulatorRate ?? "—"}%`,
    `4→5 without simulator: ${cohorts.conversionWithoutSimulatorRate ?? "—"}%`,
  ];

  return {
    generatedAt: new Date().toISOString(),
    totalReached4,
    totalReached5,
    reflection4To5ConversionRate,
    previewShownCount,
    previewClickCount,
    simulatorShownCount,
    simulatorExampleOpenedCount,
    simulatorCtaClickedCount,
    conversionWithSimulatorRate: cohorts.conversionWithSimulatorRate,
    conversionWithoutSimulatorRate: cohorts.conversionWithoutSimulatorRate,
    reached4WithSimulatorShown: cohorts.reached4WithSimulatorShown,
    reached4WithoutSimulatorShown: cohorts.reached4WithoutSimulatorShown,
    reached5AfterSimulatorShown: cohorts.reached5AfterSimulatorShown,
    reached5WithoutSimulatorShown: cohorts.reached5WithoutSimulatorShown,
    currentReflectionCount: countCompletedReflections(),
    lines,
  };
}

export function clearActivationBottleneckForEval(): void {
  if (typeof globalThis.localStorage === "undefined") return;
  const names = new Set<string>(Object.values(ACTIVATION_BOTTLENECK_EVENTS));
  const kept = readLocalEvents().filter((e) => !names.has(e.name));
  globalThis.localStorage.setItem("voicememory_local_events", JSON.stringify(kept));
}
