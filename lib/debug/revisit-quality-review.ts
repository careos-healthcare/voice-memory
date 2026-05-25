import {
  assessRevisitQuality,
  buildRevisitFatigueRiskSummary,
  collectRevisitQualityCandidates,
} from "@/lib/revisit/revisit-quality";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  RevisitQualityClassification,
  RevisitQualityDebugReport,
  RevisitQualityReviewRow,
  RevisitQualityVerdict,
} from "@/types/revisit-quality";

function toReviewRow(verdict: RevisitQualityVerdict): RevisitQualityReviewRow {
  return {
    noteId: verdict.noteId,
    entryId: verdict.entryId ?? "",
    text: verdict.text,
    total: verdict.total,
    classification: verdict.classification,
    flags: verdict.flags,
    dimensions: verdict.dimensions,
    suppressed: verdict.suppressed,
    protected: verdict.protected,
  };
}

function buildReflectionQuality(rows: RevisitQualityVerdict[]): RevisitQualityDebugReport["reflectionQuality"] {
  const loops = readRetentionLoopEvents();
  const revisits = loops.filter((event) => event.kind === "entry_revisited").length;
  const reflections = loops.filter((event) => event.kind === "followup_recording_completed").length;
  const durableCount = rows.filter((row) => row.classification === "durable_revisit").length;
  const meaningfulCount = rows.filter((row) => row.classification === "meaningful_revisit").length;

  return {
    revisitCount: revisits,
    reflectionAfterCount: reflections,
    conversionRate:
      revisits > 0 ? `${Math.round((reflections / revisits) * 100)}%` : "—",
    durableCount,
    meaningfulCount,
  };
}

export function buildRevisitQualityDebugReport(): RevisitQualityDebugReport {
  const entries = getMemoryEligibleEntries();
  const candidates = collectRevisitQualityCandidates(entries);
  const verdicts = candidates.map((note) => assessRevisitQuality(note, entries));
  const rows = verdicts.map(toReviewRow);

  const byClassification = verdicts.reduce(
    (acc, verdict) => {
      acc[verdict.classification] += 1;
      return acc;
    },
    {
      weak_revisit: 0,
      informational_revisit: 0,
      meaningful_revisit: 0,
      durable_revisit: 0,
    } satisfies Record<RevisitQualityClassification, number>,
  );

  const sorted = [...rows].sort((a, b) => b.total - a.total);
  const bestRevisits = sorted.filter((row) => !row.suppressed).slice(0, 8);
  const worstRevisits = [...rows]
    .sort((a, b) => a.total - b.total)
    .filter((row) => row.suppressed || row.classification === "weak_revisit")
    .slice(0, 8);

  const genericCopy = rows
    .filter((row) => row.flags.includes("generic_copy") || row.flags.includes("informational_only"))
    .sort((a, b) => b.dimensions.genericityRisk - a.dimensions.genericityRisk)
    .slice(0, 8);

  const overclaimedCopy = rows
    .filter((row) => row.flags.includes("overclaimed_copy"))
    .sort((a, b) => b.dimensions.overclaimRisk - a.dimensions.overclaimRisk)
    .slice(0, 8);

  return {
    generatedAt: new Date().toISOString(),
    hasData: rows.length > 0,
    totalCandidates: rows.length,
    bestRevisits,
    worstRevisits,
    genericCopy,
    overclaimedCopy,
    reflectionQuality: buildReflectionQuality(verdicts),
    fatigueRisk: buildRevisitFatigueRiskSummary(verdicts),
    byClassification,
  };
}
