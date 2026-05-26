import { readLocalEvents } from "@/lib/local-analytics";
import {
  getRecentResurfacingModes,
  RESURFACING_MODE_EVENTS,
  RESURFACING_MODE_LABELS,
  RESURFACING_RETURN_MODES,
  cadenceKey,
  type ResurfacingReturnMode,
} from "@/lib/resurfacing/return-modes";
import {
  shouldPreferMicFirstWithoutContinuityStack,
  shouldReduceResurfacingFrequency,
} from "@/lib/resurfacing/resurfacing-frequency";
import type {
  CadenceClusterRow,
  OverusedPhraseRow,
  ResurfacingFrequencyRow,
  ResurfacingModeDistributionRow,
  ResurfacingRepetitionWarning,
  ResurfacingVarietyReport,
} from "@/types/resurfacing-variety";

function ratePercent(num: number, denom: number): number {
  if (denom <= 0) return 0;
  return Math.round((num / denom) * 100);
}

function buildModeDistribution(): ResurfacingModeDistributionRow[] {
  const events = readLocalEvents();
  return RESURFACING_RETURN_MODES.map((mode) => {
    const shown = events.filter(
      (e) => e.name === RESURFACING_MODE_EVENTS.shown && e.meta?.mode === mode,
    ).length;
    const opened = events.filter(
      (e) => e.name === RESURFACING_MODE_EVENTS.opened && e.meta?.mode === mode,
    ).length;
    const reflectionAfter = events.filter(
      (e) =>
        e.name === RESURFACING_MODE_EVENTS.reflectionAfter && e.meta?.mode === mode,
    ).length;
    return {
      mode,
      label: RESURFACING_MODE_LABELS[mode],
      shown,
      opened,
      reflectionAfter,
      openRate: ratePercent(opened, shown),
      reflectionRate: ratePercent(reflectionAfter, Math.max(opened, 1)),
    };
  }).filter((row) => row.shown > 0 || row.opened > 0 || row.reflectionAfter > 0);
}

function buildRepetitionWarnings(
  recentModes: ResurfacingReturnMode[],
): ResurfacingRepetitionWarning[] {
  const warnings: ResurfacingRepetitionWarning[] = [];
  const counts = new Map<ResurfacingReturnMode, number>();
  for (const mode of recentModes) {
    counts.set(mode, (counts.get(mode) ?? 0) + 1);
  }
  for (const [mode, count] of counts) {
    if (count >= 2) {
      warnings.push({
        severity: count >= 3 ? "concern" : "watch",
        message: `${RESURFACING_MODE_LABELS[mode]} appeared ${count} times in the last ${recentModes.length} resurfacing events.`,
      });
    }
  }
  if (recentModes.length >= 3 && new Set(recentModes).size === 1) {
    warnings.push({
      severity: "concern",
      message: `Only ${RESURFACING_MODE_LABELS[recentModes[0]]} modes in the recent window — resurfacing may feel templated.`,
    });
  }
  return warnings;
}

function buildOverusedPhrases(): OverusedPhraseRow[] {
  const counts = new Map<string, number>();
  for (const event of readLocalEvents()) {
    if (event.name !== RESURFACING_MODE_EVENTS.shown) continue;
    const preview = (event.meta?.preview ?? "").trim().toLowerCase();
    if (!preview) continue;
    const key = preview.slice(0, 80);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return [...counts.entries()]
    .filter(([, count]) => count >= 2)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 8)
    .map(([phrase, count]) => ({
      phrase,
      count,
      plain:
        count >= 4
          ? "This line may be overused — variety fatigue likely."
          : "Repeated resurfacing copy on this device.",
    }));
}

function buildCadenceClusters(): CadenceClusterRow[] {
  const clusters = new Map<string, { count: number; sample: string }>();
  for (const event of readLocalEvents()) {
    if (event.name !== RESURFACING_MODE_EVENTS.shown) continue;
    const preview = event.meta?.preview ?? "";
    const key = event.meta?.cadence ?? cadenceKey(preview);
    const existing = clusters.get(key);
    if (existing) {
      existing.count += 1;
    } else {
      clusters.set(key, { count: 1, sample: preview.slice(0, 100) });
    }
  }
  return [...clusters.entries()]
    .filter(([, row]) => row.count >= 2)
    .sort((a, b) => b[1].count - a[1].count)
    .slice(0, 10)
    .map(([cadenceKeyValue, row]) => ({
      cadenceKey: cadenceKeyValue,
      count: row.count,
      sampleLine: row.sample,
      plain: "Same opening cadence clustered — consider rotating emotional structure.",
    }));
}

export function buildResurfacingVarietyReport(): ResurfacingVarietyReport {
  if (typeof window === "undefined") {
    return emptyReport();
  }

  const events = readLocalEvents();
  const recentModes = getRecentResurfacingModes();
  const modeDistribution = buildModeDistribution();
  const hasData =
    events.some((e) =>
      Object.values(RESURFACING_MODE_EVENTS).includes(
        e.name as (typeof RESURFACING_MODE_EVENTS)[keyof typeof RESURFACING_MODE_EVENTS],
      ),
    ) || modeDistribution.length > 0;

  const frequencyGates: ResurfacingFrequencyRow[] = [
    {
      label: "Reduce frequency",
      active: shouldReduceResurfacingFrequency(),
      plain: "Last three resurfacing events did not lead to a recording.",
    },
    {
      label: "Mic-first / no stack",
      active: shouldPreferMicFirstWithoutContinuityStack(),
      plain: "Homepage continuity stack suppressed — mic is the only surface.",
    },
  ];

  return {
    generatedAt: new Date().toISOString(),
    hasData,
    scopeNote:
      "This device only — mode events from local analytics. Not a multi-user cohort.",
    recentModes,
    modeDistribution,
    repetitionWarnings: buildRepetitionWarnings(recentModes),
    overusedPhrases: buildOverusedPhrases(),
    cadenceClusters: buildCadenceClusters(),
    frequencyGates,
    changeDetectionPlain:
      "Callbacks require detectable change (mood, wording, or gap) before they can rank.",
    naturalVoicePlain:
      "Synthetic openers and product-template lines are penalized; quote-led lines preferred.",
  };
}

function emptyReport(): ResurfacingVarietyReport {
  return {
    generatedAt: new Date().toISOString(),
    hasData: false,
    scopeNote: "Server render — open in browser.",
    recentModes: [],
    modeDistribution: [],
    repetitionWarnings: [],
    overusedPhrases: [],
    cadenceClusters: [],
    frequencyGates: [],
    changeDetectionPlain: "",
    naturalVoicePlain: "",
  };
}
