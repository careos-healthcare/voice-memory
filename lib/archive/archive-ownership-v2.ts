import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildEvidenceArchiveStats } from "@/lib/archive/evidence-archive-stats";
import { linkedAreasForEntries } from "@/lib/blind-spots/blind-spot-ranking";
import type { LifeAreaLabel } from "@/lib/blind-spots/blind-spot-ranking";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ArchiveHistorySummaryView,
  ArchiveMilestonesView,
} from "@/types/archive-ownership-v2";
import type { JournalEntry } from "@/types/journal";
import type { Theory } from "@/types/theory";

export const ARCHIVE_MILESTONES_HEADLINE = "Your archive now contains:";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function formatLifeAreasInline(areas: LifeAreaLabel[]): string {
  const labels = areas.slice(0, 3).map((a) => a.toLowerCase());
  if (labels.length === 0) return "";
  if (labels.length === 1) return labels[0]!;
  if (labels.length === 2) return `${labels[0]} and ${labels[1]}`;
  return `${labels.slice(0, -1).join(", ")}, and ${labels[labels.length - 1]}`;
}

function leadTheory(entries: JournalEntry[]): Theory | null {
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  return report.all[0] ?? null;
}

function beliefChallengeCount(theory: Theory): number {
  return theory.contradictingEvidence.length;
}

function evidenceEntryIds(theory: Theory): string[] {
  return [
    ...new Set([
      ...theory.supportingEvidence.map((q) => q.entryId),
      ...theory.contradictingEvidence.map((q) => q.entryId),
    ]),
  ];
}

function beliefStillStanding(theory: Theory): boolean {
  return (
    theory.status === "active" ||
    theory.status === "strengthening" ||
    theory.status === "weakening"
  );
}

export function buildArchiveMilestones(
  entriesInput?: JournalEntry[],
): ArchiveMilestonesView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const stats = buildEvidenceArchiveStats(entries);
  if (stats.reflectionCount < 1) return null;

  const items: string[] = [];

  items.push(
    `${stats.reflectionCount} saved moment${stats.reflectionCount === 1 ? "" : "s"}`,
  );

  if (stats.beliefsTracked >= 1) {
    items.push("First belief");
  }

  if (stats.daysCovered !== null) {
    items.push(
      `${stats.daysCovered} day${stats.daysCovered === 1 ? "" : "s"} of evidence`,
    );
  }

  if (stats.beliefChangesRecorded >= 1) {
    items.push(
      `${stats.beliefChangesRecorded} belief change${stats.beliefChangesRecorded === 1 ? "" : "s"}`,
    );
  }

  return { headline: ARCHIVE_MILESTONES_HEADLINE, items };
}

export function buildArchiveHistorySummary(
  entriesInput?: JournalEntry[],
): ArchiveHistorySummaryView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const stats = buildEvidenceArchiveStats(entries);
  if (stats.reflectionCount < 1) return null;

  const lines: string[] = [];

  if (stats.daysCovered !== null && stats.daysCovered >= 2) {
    lines.push(
      `This archive has been evolving for ${stats.daysCovered} day${stats.daysCovered === 1 ? "" : "s"}.`,
    );
  }

  const theory = leadTheory(entries);
  const belief = buildArchiveBeliefView(entries);
  if (theory && belief && beliefStillStanding(theory)) {
    const challenges = beliefChallengeCount(theory);
    if (challenges >= 1) {
      lines.push(
        `This belief survived ${challenges} challenge${challenges === 1 ? "" : "s"}.`,
      );
    }
  }

  if (theory) {
    const areas = linkedAreasForEntries(entries, evidenceEntryIds(theory));
    if (areas.length >= 2) {
      const spread = formatLifeAreasInline(areas);
      lines.push(`This archive contains evidence from ${spread}.`);
    }
  }

  if (lines.length === 0) return null;
  return { lines };
}
