import { buildArchiveDepthReport } from "@/lib/debug/archive-depth-review";
import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildMemoryCompoundingReport } from "@/lib/memory/memory-compounding";
import { buildSlowRealizationReport } from "@/lib/memory/slow-realizations";
import { buildDurableCallbacksReport } from "@/lib/refinement/durable-callbacks";
import { buildRevisitSequencingReport } from "@/lib/refinement/revisit-sequencing";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { ArchiveMaturityReport } from "@/types/memory-compounding";

function monthOverMonthContinuity(entries: JournalEntry[]): Array<{ month: string; score: number }> {
  const buckets = new Map<string, number>();

  for (const entry of entries) {
    const month = entry.createdAt.slice(0, 7);
    buckets.set(month, (buckets.get(month) ?? 0) + 1);
  }

  return [...buckets.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .slice(-8)
    .map(([month, count]) => ({
      month,
      score: Math.min(100, count * 12),
    }));
}

function revisitFatigueWarnings(sequencing: ReturnType<typeof buildRevisitSequencingReport>): string[] {
  const warnings: string[] = [];
  if (sequencing.revisitFatigueActive) {
    warnings.push(`Revisit fatigue — ${sequencing.fatigueScore} revisits in the last week`);
  }
  if (sequencing.suppressedAdjacentCount > 3) {
    warnings.push("Emotionally adjacent revisits suppressed to spread payoff");
  }
  if (sequencing.recommendedSpacingDays >= 14) {
    warnings.push(`Spacing widened to ${sequencing.recommendedSpacingDays} days after heavy reopen`);
  }
  return warnings;
}

export function buildArchiveMaturityReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): ArchiveMaturityReport {
  const compounding = buildMemoryCompoundingReport(entries);
  const slowRealizations = buildSlowRealizationReport(entries);
  const archiveDepth = buildArchiveDepthReport(entries);
  const revisitSequencing = buildRevisitSequencingReport();
  const durableCallbacks = buildDurableCallbacksReport(entries);
  const callbackReport = buildCallbackQualityReviewReport(entries);

  const longitudinalResidueLeaders = callbackReport.items
    .filter((i) => i.emotionalResidueScore >= 45)
    .sort((a, b) => b.emotionalResidueScore - a.emotionalResidueScore)
    .slice(0, 10)
    .map((i) => ({
      id: i.id,
      text: i.text,
      score: i.emotionalResidueScore,
    }));

  return {
    generatedAt: new Date().toISOString(),
    hasData: entries.length >= 6 || archiveDepth.hasData,
    compounding,
    slowRealizations,
    archiveDepth,
    revisitSequencing,
    durableCallbacks,
    revisitFatigueWarnings: revisitFatigueWarnings(revisitSequencing),
    monthOverMonthContinuity: monthOverMonthContinuity(entries),
    longitudinalResidueLeaders,
  };
}

export function downloadArchiveMaturityJson(
  report: ArchiveMaturityReport = buildArchiveMaturityReport(),
): void {
  if (typeof window === "undefined") return;

  const blob = new Blob([JSON.stringify(report, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "archive-maturity.json";
  anchor.click();
  URL.revokeObjectURL(url);
}

export function downloadArchiveDepthJson(
  report: ReturnType<typeof buildArchiveDepthReport> = buildArchiveDepthReport(),
): void {
  if (typeof window === "undefined") return;

  const blob = new Blob([JSON.stringify(report, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "archive-depth.json";
  anchor.click();
  URL.revokeObjectURL(url);
}
