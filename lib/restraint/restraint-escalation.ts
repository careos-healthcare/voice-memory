import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { RestraintEscalationReport } from "@/types/sacredness-layer";

function sorted(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function archiveSpanDays(entries: JournalEntry[]): number {
  if (entries.length < 2) return 0;
  const s = sorted(entries);
  return daysBetweenKeys(toDayKey(s[0].createdAt), toDayKey(s[s.length - 1].createdAt));
}

/** Restraint escalation — mature archives become more spacious, not denser. */
export function buildRestraintEscalationReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): RestraintEscalationReport {
  const count = entries.length;
  const span = archiveSpanDays(entries);

  let level = 0;
  if (count >= 12 || span >= 60) level = 1;
  if (count >= 24 || span >= 120) level = 2;
  if (count >= 40 || span >= 240) level = 3;

  const showThresholdBoost = level * 6;
  const resurfacingReduction = level * 15;
  const silenceBias = level * 12;
  const evidenceRequirement = level * 10;

  const early = sorted(entries).slice(0, Math.max(2, Math.floor(count / 3)));
  const recent = sorted(entries).slice(Math.floor((count * 2) / 3));
  const earlyGap =
    early.length >= 2
      ? daysBetweenKeys(toDayKey(early[0].createdAt), toDayKey(early[early.length - 1].createdAt)) /
        Math.max(early.length - 1, 1)
      : 0;
  const recentGap =
    recent.length >= 2
      ? daysBetweenKeys(toDayKey(recent[0].createdAt), toDayKey(recent[recent.length - 1].createdAt)) /
        Math.max(recent.length - 1, 1)
      : 0;

  const becomingMoreSpacious = recentGap >= earlyGap * 0.9 || level >= 2;

  return {
    generatedAt: new Date().toISOString(),
    hasData: count > 0,
    level,
    entryCount: count,
    archiveSpanDays: span,
    showThresholdBoost,
    resurfacingReduction,
    silenceBias,
    evidenceRequirement,
    becomingMoreSpacious,
  };
}

export function escalatedShowThreshold(base: number, entries?: JournalEntry[]): number {
  const escalation = buildRestraintEscalationReport(entries);
  return base + escalation.showThresholdBoost;
}

export function escalatedResurfacingCap(base: number, entries?: JournalEntry[]): number {
  const escalation = buildRestraintEscalationReport(entries);
  return Math.max(1, Math.round(base * (1 - escalation.resurfacingReduction / 100)));
}

export function archiveMaturityLevel(entries?: JournalEntry[]): number {
  return buildRestraintEscalationReport(entries).level;
}
