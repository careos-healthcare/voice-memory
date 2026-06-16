/**
 * Internal-only archive value score (0–100). Drives CTA timing; never show raw score in UI.
 */

import { readBeliefRecallRecords } from "@/lib/retention/belief-recall";
import { readArchiveAttachmentRecords } from "@/lib/archive/archive-attachment";
import { buildEvidenceArchiveStats } from "@/lib/archive/evidence-archive-stats";
import { buildEvidenceLocker } from "@/lib/archive/evidence-locker";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export interface ArchiveValueScoreInput {
  reflectionCount: number;
  daysCovered: number | null;
  beliefsTracked: number;
  beliefChangesRecorded: number;
  evidenceQuotesStored: number;
  contradictionCount: number;
  costEvidenceCount: number;
  recallStrongCount: number;
  attachmentStrongCount: number;
}

export interface ArchiveValueScoreResult {
  score: number;
  input: ArchiveValueScoreInput;
}

const PROTECT_THRESHOLD = 40;
const EXPORT_THRESHOLD = 30;
const REFERRAL_THRESHOLD = 55;
const PRO_CONTINUITY_THRESHOLD = 50;

function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n));
}

export function computeArchiveValueScoreFromInput(
  input: ArchiveValueScoreInput,
): ArchiveValueScoreResult {
  let score = 0;
  score += clamp(input.reflectionCount * 4, 0, 28);
  if (input.daysCovered !== null) {
    score += clamp(Math.floor(input.daysCovered / 3), 0, 12);
  }
  score += clamp(input.beliefsTracked * 3, 0, 12);
  score += clamp(input.beliefChangesRecorded * 2, 0, 10);
  score += clamp(Math.floor(input.evidenceQuotesStored / 2), 0, 14);
  score += clamp(input.contradictionCount * 3, 0, 9);
  score += clamp(input.costEvidenceCount * 2, 0, 6);
  score += clamp(input.recallStrongCount * 5, 0, 10);
  score += clamp(input.attachmentStrongCount * 4, 0, 9);

  return { score: clamp(score, 0, 100), input };
}

export function computeArchiveValueScore(
  entriesInput?: JournalEntry[],
): ArchiveValueScoreResult {
  const entries = entriesInput ?? getMemoryEligibleEntries();
  const stats = buildEvidenceArchiveStats(entries);
  const locker = buildEvidenceLocker(entries);
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });

  let contradictionCount = 0;
  let costEvidenceCount = 0;
  for (const t of report.all) {
    contradictionCount += t.contradictingEvidence.length;
  }
  costEvidenceCount = locker.items.filter((i) => i.tag === "cost").length;

  const recallStrongCount = readBeliefRecallRecords().filter(
    (r) => r.level === "yes_clearly" || r.level === "vaguely",
  ).length;

  const attachmentStrongCount = readArchiveAttachmentRecords().filter(
    (r) => r.level === "very" || r.level === "extremely",
  ).length;

  return computeArchiveValueScoreFromInput({
    reflectionCount: stats.reflectionCount,
    daysCovered: stats.daysCovered,
    beliefsTracked: stats.beliefsTracked,
    beliefChangesRecorded: stats.beliefChangesRecorded,
    evidenceQuotesStored: stats.evidenceQuotesStored,
    contradictionCount,
    costEvidenceCount,
    recallStrongCount,
    attachmentStrongCount,
  });
}

export function shouldEmphasizeProtectArchive(entriesInput?: JournalEntry[]): boolean {
  return computeArchiveValueScore(entriesInput).score >= PROTECT_THRESHOLD;
}

export function shouldEmphasizeExportArchive(entriesInput?: JournalEntry[]): boolean {
  return computeArchiveValueScore(entriesInput).score >= EXPORT_THRESHOLD;
}

export function shouldEmphasizeReferralPrompt(entriesInput?: JournalEntry[]): boolean {
  return computeArchiveValueScore(entriesInput).score >= REFERRAL_THRESHOLD;
}

export function shouldEmphasizeProContinuity(entriesInput?: JournalEntry[]): boolean {
  return computeArchiveValueScore(entriesInput).score >= PRO_CONTINUITY_THRESHOLD;
}
