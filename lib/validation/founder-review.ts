import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { sortByEmotionalSurvival } from "@/lib/debug/callback-quality-score";
import { buildMonetizationReadinessReport } from "@/lib/observation/monetization-readiness";
import { buildProductionReadinessReport } from "@/lib/observation/production-readiness";
import { buildReopenPayoffDebugReport } from "@/lib/refinement/reopen-payoff";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import { buildSyncHealthReport } from "@/lib/sync/sync-health";
import { buildIncidentBundle } from "@/lib/validation/incidents";
import {
  buildEmotionalResidueSummary,
  readWeeklyRetentionSnapshots,
} from "@/lib/validation/observation-summaries";
import { readTesterFeedback } from "@/lib/validation/tester-feedback";
import { getAllEntries } from "@/lib/storage";
import type { FounderReviewRankedItem, FounderReviewReport } from "@/types/validation-phase";

function ranked(
  id: string,
  label: string,
  detail?: string,
  score?: number,
): FounderReviewRankedItem {
  return { id, label, detail, score };
}

/** One-page founder overview — debug only, ranked lists, no charts. */
export async function buildFounderReviewReport(): Promise<FounderReviewReport> {
  const entries = getAllEntries();
  const callbackReport = buildCallbackQualityReviewReport(entries);
  const loops = buildRetentionLoopReport();
  const reopen = buildReopenPayoffDebugReport(entries);
  const [production, monetization, syncHealth, incidents] = await Promise.all([
    buildProductionReadinessReport(),
    buildMonetizationReadinessReport(),
    buildSyncHealthReport(),
    buildIncidentBundle(),
  ]);

  const strongestCallbacks = sortByEmotionalSurvival(callbackReport.items)
    .filter((item) => item.survival.emotionalSurvivalScore >= 35 || item.doubleDown)
    .slice(0, 8)
    .map((item) =>
      ranked(
        item.id,
        item.text.slice(0, 120),
        `survival ${item.survival.emotionalSurvivalScore} · residue ${item.emotionalResidueScore}`,
        item.survival.emotionalSurvivalScore,
      ),
    );

  const deadCallbacks = callbackReport.items
    .filter(
      (item) =>
        item.cutCandidate ||
        item.survival.emotionalSurvivalScore < 22 ||
        item.survival.lowSurvivalCutCandidate,
    )
    .slice(0, 8)
    .map((item) =>
      ranked(
        item.id,
        item.text.slice(0, 120),
        `survival ${item.survival.emotionalSurvivalScore} · ${item.cutCandidate ? "cut candidate" : "low survival"}`,
        item.survival.emotionalSurvivalScore,
      ),
    );

  const strongestRevisitMoments = [
    ...loops.revisitsCausingReflections
      .filter((row) => row.reflectionEntryId)
      .slice(0, 5)
      .map((row) =>
        ranked(
          row.entryId,
          `Revisit → reflection ${row.reflectionEntryId?.slice(0, 8) ?? ""}`,
          row.sources,
        ),
      ),
    ...reopen.moments
      .filter((row) => !row.suppressed && row.payoffScore >= 54)
      .slice(0, 5)
      .map((row) =>
        ranked(row.entryId, row.firstLine.slice(0, 120), `payoff ${row.payoffScore}`),
      ),
    ...loops.notesCausingRevisits
      .filter((row) => row.oldEntryOpens > 0 || row.clicks > 0)
      .slice(0, 5)
      .map((row) =>
        ranked(
          row.noteId,
          row.noteText.slice(0, 120),
          `${row.clicks} clicks · ${row.oldEntryOpens} opens`,
        ),
      ),
  ].slice(0, 10);

  const emotionalResidueLeaders = buildEmotionalResidueSummary()
    .slice(0, 10)
    .map((row) =>
      ranked(
        row.id,
        row.text.slice(0, 120),
        row.source === "manual_note"
          ? [row.feltRemembered ? "felt remembered" : null, row.feltGeneric ? "felt generic" : null, row.wouldPay ? `pay: ${row.wouldPay}` : null]
              .filter(Boolean)
              .join(" · ") || "manual note"
          : "callback residue",
      ),
    );

  const trustFailures = [
    ...production.checks
      .filter((row) => row.status === "fail")
      .map((row) => ranked(row.id, row.label, row.detail)),
    ...syncHealth.issues.map((row, index) =>
      ranked(`sync-${index}`, row.type, row.detail, undefined),
    ),
  ].slice(0, 12);

  const syncHealthSummary = [
    syncHealth.lastBackupAt ? `Last backup: ${syncHealth.lastBackupAt}` : "No backup timestamp",
    syncHealth.lastSyncedAt ? `Last sync: ${syncHealth.lastSyncedAt}` : "No sync timestamp",
    syncHealth.lastSyncError ? `Last error: ${syncHealth.lastSyncError.slice(0, 100)}` : "No sync error recorded",
    `${syncHealth.issues.length} open sync issue(s)`,
    `${syncHealth.audioBackupStatus.localWithAudio} local audio · ${syncHealth.audioBackupStatus.remoteBackedUp} remote`,
  ];

  const feedback = readTesterFeedback();

  return {
    generatedAt: new Date().toISOString(),
    strongestCallbacks,
    deadCallbacks,
    strongestRevisitMoments,
    emotionalResidueLeaders,
    trustFailures,
    syncHealthSummary,
    monetizationHeadline: monetization.headline,
    monetizationVerdict: monetization.verdict,
    retentionTrend: readWeeklyRetentionSnapshots(),
    openIncidents: incidents.openCount,
    testerFeedbackCount: feedback.length,
  };
}

export function downloadFounderReviewJson(report: FounderReviewReport): void {
  if (typeof window === "undefined") return;

  const blob = new Blob([JSON.stringify(report, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `founder-review-${report.generatedAt.slice(0, 10)}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
}
