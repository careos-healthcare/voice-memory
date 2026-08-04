import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildEvidenceArchiveStats } from "@/lib/archive/evidence-archive-stats";
import {
  shouldEmphasizeExportArchive,
  shouldEmphasizeProContinuity,
  shouldEmphasizeProtectArchive,
} from "@/lib/archive/archive-value-score";
import { readBeliefRecallRecords } from "@/lib/retention/belief-recall";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveWorthCtaId, ArchiveWorthSnapshot } from "@/types/archive-worth";
import type { JournalEntry } from "@/types/journal";

export const ARCHIVE_WORTH_HEADLINE = "Your archive would be hard to rebuild.";

function formatDateLabel(iso: string): string {
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(new Date(iso));
}

function countWorkingBeliefs(entries: JournalEntry[]): number {
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  return report.all.filter(
    (t) =>
      t.status === "active" ||
      t.status === "strengthening" ||
      t.status === "weakening",
  ).length;
}

function strongestRememberedBelief(entries: JournalEntry[]): string | null {
  const belief = buildArchiveBeliefView(entries);
  const records = readBeliefRecallRecords();
  const strong = records.find(
    (r) =>
      (r.level === "yes_clearly" || r.level === "vaguely") &&
      (!belief || r.theoryId === belief.theoryId),
  );
  if (strong?.note?.trim()) return strong.note.trim();
  if (belief) return belief.belief;
  return null;
}

export function buildArchiveWorthSummaryLine(
  snapshot: Omit<
    ArchiveWorthSnapshot,
    "headline" | "summaryLine" | "suggestedCtas"
  >,
): string {
  const days =
    snapshot.daysCovered !== null
      ? ` across ${snapshot.daysCovered} day${snapshot.daysCovered === 1 ? "" : "s"}`
      : "";
  const beliefs =
    snapshot.workingBeliefs > 0
      ? `${snapshot.workingBeliefs} working belief${snapshot.workingBeliefs === 1 ? "" : "s"}`
      : `${snapshot.beliefsTracked} belief${snapshot.beliefsTracked === 1 ? "" : "s"} tracked`;
  return `Your archive contains ${snapshot.reflectionCount} saved moment${snapshot.reflectionCount === 1 ? "" : "s"}${days}, ${beliefs}, and ${snapshot.evidenceQuotesStored} evidence quote${snapshot.evidenceQuotesStored === 1 ? "" : "s"}.`;
}

function resolveCtas(entries: JournalEntry[], isSignedIn: boolean): ArchiveWorthCtaId[] {
  const ctas: ArchiveWorthCtaId[] = [];
  if (!isSignedIn && shouldEmphasizeProtectArchive(entries)) {
    ctas.push("protect_archive");
  }
  if (shouldEmphasizeExportArchive(entries)) {
    ctas.push("export_archive");
  }
  if (shouldEmphasizeProContinuity(entries)) {
    ctas.push("pro_continuity");
  }
  if (ctas.length === 0 && !isSignedIn) {
    ctas.push("protect_archive");
  }
  return ctas;
}

export function buildArchiveWorthSnapshot(
  entriesInput?: JournalEntry[],
  options?: { isSignedIn?: boolean },
): ArchiveWorthSnapshot | null {
  const entries = (entriesInput ?? getMemoryEligibleEntries()).filter(
    (e) => e.reflectionPending !== true,
  );
  if (entries.length === 0) return null;

  const stats = buildEvidenceArchiveStats(entries);
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const firstReflectionDateLabel = sorted[0]
    ? formatDateLabel(sorted[0].createdAt)
    : null;
  const workingBeliefs = countWorkingBeliefs(entries);
  const strongestRemembered = strongestRememberedBelief(entries);

  const partial = {
    reflectionCount: stats.reflectionCount,
    daysCovered: stats.daysCovered,
    workingBeliefs,
    beliefsTracked: stats.beliefsTracked,
    beliefChangesRecorded: stats.beliefChangesRecorded,
    evidenceQuotesStored: stats.evidenceQuotesStored,
    firstReflectionDateLabel,
    strongestRememberedBelief: strongestRemembered,
  };

  return {
    headline: ARCHIVE_WORTH_HEADLINE,
    summaryLine: buildArchiveWorthSummaryLine(partial),
    ...partial,
    suggestedCtas: resolveCtas(entries, options?.isSignedIn ?? false),
  };
}
