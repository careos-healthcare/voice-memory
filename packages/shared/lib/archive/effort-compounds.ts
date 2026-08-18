import { readLocalEvents } from "@/lib/local-analytics";
import { VALUE_MOMENT_PAYWALL_EVENTS } from "@/lib/billing/value-moment-paywall-metrics";
import { isProTier } from "@/lib/entitlement/entitlements";
import { buildArchiveValueSnapshot } from "@/lib/product/archive-value-progress";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export const EFFORT_COMPOUNDS_REFLECTION_COUNTS = [2, 4, 5, 6] as const;

export type EffortCompoundsTrigger = "reflection_count" | "post_paywall" | "export";

export interface EffortCompoundsVisibility {
  show: boolean;
  reflectionCount: number;
  trigger: EffortCompoundsTrigger | null;
}

function hasSeenPaywall(): boolean {
  const names = new Set<string>(Object.values(VALUE_MOMENT_PAYWALL_EVENTS));
  return readLocalEvents().some((e) => names.has(e.name));
}

export function buildEffortCompoundsVisibility(
  entriesInput?: JournalEntry[],
  options?: { surface?: "export" },
): EffortCompoundsVisibility {
  const entries = entriesInput ?? getMemoryEligibleEntries();
  const { reflectionCount } = buildArchiveValueSnapshot(entries);

  if (options?.surface === "export") {
    return { show: reflectionCount >= 1, reflectionCount, trigger: "export" };
  }

  if (isProTier() || hasSeenPaywall()) {
    return { show: true, reflectionCount, trigger: "post_paywall" };
  }

  if ((EFFORT_COMPOUNDS_REFLECTION_COUNTS as readonly number[]).includes(reflectionCount)) {
    return { show: true, reflectionCount, trigger: "reflection_count" };
  }

  return { show: false, reflectionCount, trigger: null };
}
