import { buildCostEvidence } from "@/lib/blind-spots/cost-evidence";
import { buildEmergingPatterns } from "@/lib/blind-spots/emerging-patterns";
import { BLIND_SPOT_MIN_REFLECTIONS } from "@/lib/blind-spots/blind-spot-copy";
import {
  linkedAreasForEntries,
} from "@/lib/blind-spots/blind-spot-ranking";
import {
  ARCHIVE_VALUE_STAGE_COPY,
  PATTERN_REVIEW_TARGET,
} from "@/lib/product/archive-value-copy";
import {
  nextEvidenceMilestoneCopy,
  stageForReflectionCount as evidenceStageForCount,
} from "@/lib/theories/personal-theory-status";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import {
  buildPatternEngineReport,
  type PatternInsightType,
} from "@/lib/patterns/pattern-engine";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveValueSnapshot, ArchiveValueStage } from "@/types/archive-value";
import type { JournalEntry } from "@/types/journal";

const BLOCKED_THEMES = new Set(["general", "other", "misc", "stress", "work"]);
const PATTERN_TYPES = new Set<PatternInsightType>([
  "contradiction",
  "avoidance_signal",
  "repeated_phrase",
  "recurring_pattern",
]);

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter(
    (e) =>
      e.reflectionPending !== true &&
      typeof e.transcript === "string" &&
      e.transcript.trim().length > 0,
  );
}

export function stageForReflectionCount(count: number): ArchiveValueStage {
  return evidenceStageForCount(count);
}

function countRepeatedThemes(entries: JournalEntry[]): number {
  const themeHits = new Map<string, number>();
  for (const entry of entries) {
    for (const raw of entry.reflection.recurringThemes ?? []) {
      const theme = raw.trim().toLowerCase();
      if (!theme || BLOCKED_THEMES.has(theme)) continue;
      themeHits.set(theme, (themeHits.get(theme) ?? 0) + 1);
    }
  }
  return [...themeHits.values()].filter((n) => n >= 2).length;
}

function countPatternSignals(entries: JournalEntry[]): {
  crossLifeAreaPatternCount: number;
  contradictionCount: number;
  costEvidenceCount: number;
} {
  if (entries.length < 2) {
    return { crossLifeAreaPatternCount: 0, contradictionCount: 0, costEvidenceCount: 0 };
  }

  const report = buildPatternEngineReport(entries, { scope: "archive", limit: 24 });
  let crossLifeAreaPatternCount = 0;
  let contradictionCount = 0;
  let costEvidenceCount = 0;

  for (const insight of report.insights) {
    if (!PATTERN_TYPES.has(insight.type)) continue;
    const areas = linkedAreasForEntries(entries, insight.entryIds);
    if (areas.length >= 2) crossLifeAreaPatternCount += 1;
    if (insight.type === "contradiction") contradictionCount += 1;
    const cost = buildCostEvidence(insight.entryIds, entries);
    if (Object.values(cost).reduce((s, n) => s + n, 0) > 0) costEvidenceCount += 1;
  }

  return { crossLifeAreaPatternCount, contradictionCount, costEvidenceCount };
}

function nextMilestoneCopy(count: number): string {
  return nextEvidenceMilestoneCopy(count);
}

export function buildArchiveValueSnapshot(
  entriesInput?: JournalEntry[],
): ArchiveValueSnapshot {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const reflectionCount = entries.length;
  const stage = stageForReflectionCount(reflectionCount);
  const stageCopy = ARCHIVE_VALUE_STAGE_COPY[stage];
  const readyForPatternReview = reflectionCount >= BLIND_SPOT_MIN_REFLECTIONS;

  const repeatedThemeCount = Math.max(
    countRepeatedThemes(entries),
    reflectionCount >= 2 ? buildEmergingPatterns(entries).length : 0,
  );

  let theoriesUnderReviewCount = 0;
  if (reflectionCount >= 2) {
    const theoryReport = buildTheoryTrackerReport(entries, { persistSnapshots: false });
    theoriesUnderReviewCount =
      theoryReport.active.length + theoryReport.strengthening.length;
  }

  const patternSignals = countPatternSignals(entries);
  const progressPercent = Math.min(
    100,
    Math.round((Math.min(reflectionCount, PATTERN_REVIEW_TARGET) / PATTERN_REVIEW_TARGET) * 100),
  );

  return {
    reflectionCount,
    stage,
    repeatedThemeCount,
    theoriesUnderReviewCount,
    ...patternSignals,
    nextMilestoneCopy: nextMilestoneCopy(reflectionCount),
    valueCopy: stageCopy.valueCopy,
    progressPercent,
    readyForPatternReview,
    ctaHref: readyForPatternReview ? "/blind-spots" : "/#recorder",
    ctaLabel: readyForPatternReview ? "Open first working theory" : "Add another reflection",
  };
}

/** Compact line after saving a reflection. */
export function buildArchiveChangedMessage(
  entriesInput?: JournalEntry[],
): string {
  const snapshot = buildArchiveValueSnapshot(entriesInput);
  const count = snapshot.reflectionCount;

  if (count <= 0) return "Your archive is waiting for a first reflection.";
  if (count === 1) return "Your archive now has 1 reflection.";
  if (count === 2) {
    return `Your archive now has ${count} reflections. ArchiveMe can now check for possible repeats.`;
  }
  if (count >= PATTERN_REVIEW_TARGET) {
    return `Your archive now has ${count} reflections. ${snapshot.valueCopy}`;
  }
  return `Your archive now has ${count} reflections. ${snapshot.nextMilestoneCopy}`;
}

export function shouldShowArchiveValueBanner(reflectionCount?: number): boolean {
  const count =
    reflectionCount ?? buildArchiveValueSnapshot().reflectionCount;
  return count >= 1 && count <= PATTERN_REVIEW_TARGET + 24;
}
