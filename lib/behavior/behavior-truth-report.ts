import { readLocalEvents } from "@/lib/local-analytics";
import { computeBehaviorFunnels } from "@/lib/behavior/funnels";
import { computeReturnTiming, computeUserReturnSegments } from "@/lib/behavior/return-analysis";
import {
  computeCopyEffectiveness,
  pickStrongestCopy,
  pickWeakCopy,
} from "@/lib/behavior/copy-effectiveness";
import { computeMobileBehavior } from "@/lib/behavior/mobile-behavior";
import { computeProductPressureWarnings } from "@/lib/behavior/product-pressure";
import {
  computeSurfaceEffectiveness,
  pickIgnoredSurfaces,
  pickStrongestSurfaces,
} from "@/lib/behavior/surface-effectiveness";
import { buildBehaviorInsightSummary } from "@/lib/behavior/insight-summary";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { BehaviorTruthReport } from "@/types/behavior-truth";

export function buildBehaviorTruthReport(): BehaviorTruthReport {
  if (typeof window === "undefined") {
    return emptyReport();
  }

  const events = readLocalEvents();
  const entries = getMemoryEligibleEntries();
  const hasData = events.length > 0 || entries.length > 0;

  const funnels = computeBehaviorFunnels(events, entries);
  const timing = computeReturnTiming(events, entries);
  const segments = computeUserReturnSegments(events, entries);
  const surfaces = computeSurfaceEffectiveness(events);
  const copyRows = computeCopyEffectiveness(events);
  const mobile = computeMobileBehavior(events, entries);
  const productPressure = computeProductPressureWarnings(events, entries);

  const strongestSurfaces = pickStrongestSurfaces(surfaces);
  const ignoredSurfaces = pickIgnoredSurfaces(surfaces);
  const strongestCopy = pickStrongestCopy(copyRows);
  const weakCopy = pickWeakCopy(copyRows);

  const partial = {
    funnels,
    surfaces,
    copyRows,
    ignoredSurfaces,
    strongestSurfaces,
    weakCopy,
    userSegments: segments,
    productPressure,
  };

  const insights = buildBehaviorInsightSummary(partial);

  return {
    generatedAt: new Date().toISOString(),
    hasData,
    scopeNote:
      "This device only — local events and archive timestamps. Percentages are not a multi-user cohort view.",
    funnels,
    returnTiming: timing,
    userSegments: segments,
    surfaces,
    strongestSurfaces,
    ignoredSurfaces,
    copyRows,
    strongestCopy,
    weakCopy,
    mobile,
    productPressure,
    insights,
  };
}

function emptyReport(): BehaviorTruthReport {
  return {
    generatedAt: new Date().toISOString(),
    hasData: false,
    scopeNote: "Server render — open in browser.",
    funnels: [],
    returnTiming: [],
    userSegments: [],
    surfaces: [],
    strongestSurfaces: [],
    ignoredSurfaces: [],
    copyRows: [],
    strongestCopy: [],
    weakCopy: [],
    mobile: [],
    productPressure: [],
    insights: [],
  };
}
