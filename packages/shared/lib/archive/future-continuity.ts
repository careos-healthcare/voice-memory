import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { readAllCallbackReviews } from "@/lib/debug/callback-review-labels";
import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import { buildDurableCallbacksReport } from "@/lib/refinement/durable-callbacks";
import { buildRevisitSequencingReport } from "@/lib/refinement/revisit-sequencing";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  ContinuityIntegrityCheck,
  FutureContinuityReport,
} from "@/types/archive-permanence-layer";

function stableCallbackIds(entries: JournalEntry[]): string[] {
  const reviews = readAllCallbackReviews();
  const callbackReport = buildCallbackQualityReviewReport(entries);
  const ids = new Set<string>();

  for (const review of reviews) {
    if (review.callbackId) ids.add(review.callbackId);
  }

  for (const item of callbackReport.items) {
    if (item.emotionalResidueScore >= 30 || item.survival.oldEntryRevisitCount > 0) {
      ids.add(item.id);
    }
  }

  const durable = buildDurableCallbacksReport(entries);
  for (const leader of durable.leaders) {
    ids.add(leader.id);
  }

  return [...ids].sort();
}

function countRevisitLineage(): number {
  const loops = buildRetentionLoopReport();
  const lineage = new Set<string>();

  for (const link of loops.revisitsCausingReflections) {
    if (link.noteId && link.entryId) {
      lineage.add(`${link.noteId}->${link.entryId}`);
    }
  }

  for (const note of loops.notesCausingRevisits) {
    if (note.oldEntryOpens > 0) {
      lineage.add(`${note.noteId}:revisit`);
    }
  }

  return lineage.size;
}

function countQuotePairs(entries: JournalEntry[]): number {
  const loops = buildRetentionLoopReport();
  let pairs = 0;

  for (const note of loops.notesCausingRevisits) {
    const entry = entries.find((e) => e.id === note.noteId);
    if (!entry) continue;
    const hasPast =
      entry.reflection.exactLanguagePattern?.trim() ||
      entry.reflection.concreteObservation?.trim();
    if (hasPast && note.oldEntryOpens > 0) pairs += 1;
  }

  for (const link of loops.revisitsCausingReflections.filter((l) => l.reflectionEntryId)) {
    pairs += 1;
  }

  return pairs;
}

function countDurableEntryLinks(entries: JournalEntry[]): number {
  const loops = buildRetentionLoopReport();
  const durable = buildDurableCallbacksReport(entries);
  const linked = new Set<string>();

  for (const leader of durable.leaders) {
    linked.add(leader.id);
  }

  for (const note of loops.notesCausingRevisits.filter((n) => n.oldEntryOpens >= 2)) {
    linked.add(note.noteId);
  }

  return linked.size;
}

function buildChecks(
  entries: JournalEntry[],
  stableIds: string[],
  quotePairs: number,
): ContinuityIntegrityCheck[] {
  const sequencing = buildRevisitSequencingReport();
  const loops = buildRetentionLoopReport();
  const checks: ContinuityIntegrityCheck[] = [];

  checks.push({
    id: "stable-callback-ids",
    label: "Stable callback ids",
    ok: stableIds.length > 0 || entries.length < 6,
    detail:
      stableIds.length > 0
        ? `${stableIds.length} callback ids tracked across revisits and reviews`
        : "Not enough callback history yet",
  });

  checks.push({
    id: "revisit-lineage",
    label: "Revisit lineage",
    ok: loops.revisitsCausingReflections.length > 0 || entries.length < 8,
    detail: `${loops.revisitsCausingReflections.length} revisit-to-reflection links recorded`,
  });

  checks.push({
    id: "quote-pair-persistence",
    label: "Quote-pair persistence",
    ok: quotePairs > 0 || entries.length < 10,
    detail: `${quotePairs} quote pairs tied to reopen behavior`,
  });

  checks.push({
    id: "resurfacing-consistency",
    label: "Resurfacing consistency",
    ok: !sequencing.revisitFatigueActive || sequencing.recommendedSpacingDays <= 21,
    detail: sequencing.revisitFatigueActive
      ? `Fatigue active — spacing at ${sequencing.recommendedSpacingDays} days`
      : "Resurfacing cadence within expected bounds",
  });

  const duplicateReopen = loops.notesCausingRevisits.filter((n) => n.oldEntryOpens >= 5).length;
  checks.push({
    id: "reopen-repetition",
    label: "Reopen repetition",
    ok: duplicateReopen <= 2,
    detail:
      duplicateReopen > 2
        ? `${duplicateReopen} callbacks reopened heavily — repetition risk`
        : "Reopen repetition within calm bounds",
  });

  return checks;
}

/** Track migration-safe continuity for callbacks, revisits, and quote pairs. */
export function buildFutureContinuityReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): FutureContinuityReport {
  const stableIds = stableCallbackIds(entries);
  const revisitLineageCount = countRevisitLineage();
  const quotePairCount = countQuotePairs(entries);
  const durableEntryLinks = countDurableEntryLinks(entries);
  const checks = buildChecks(entries, stableIds, quotePairCount);

  const failed = checks.filter((c) => !c.ok);

  return {
    generatedAt: new Date().toISOString(),
    hasData: entries.length > 0,
    stableCallbackIds: stableIds,
    revisitLineageCount,
    quotePairCount,
    durableEntryLinks,
    checks,
    migrationPreview: {
      resurfacingConsistent: checks.find((c) => c.id === "resurfacing-consistency")?.ok !== false,
      quotePairsPersist: quotePairCount > 0 || entries.length < 10,
      callbackIdsStable: stableIds.length > 0 || entries.length < 6,
    },
  };
}

export function validateResurfacingConsistency(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): boolean {
  const report = buildFutureContinuityReport(entries);
  return report.migrationPreview.resurfacingConsistent;
}

export function previewMigrationContinuity(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): FutureContinuityReport["migrationPreview"] {
  return buildFutureContinuityReport(entries).migrationPreview;
}

export function runContinuityIntegrityChecks(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): ContinuityIntegrityCheck[] {
  return buildFutureContinuityReport(entries).checks;
}
