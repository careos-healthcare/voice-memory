import { buildEmotionalLegitimacyReport } from "@/lib/debug/emotional-legitimacy-review";
import { buildArchiveAttachmentReport } from "@/lib/research/archive-attachment";
import { buildFounderWarningsReport } from "@/lib/research/founder-warnings";
import { buildRolloutGatesReport, rolloutStageLabel } from "@/lib/research/rollout-gates";
import { buildWillingnessSignalsReport } from "@/lib/research/willingness-signals";
import { buildRetentionObservationSnapshot } from "@/lib/research/retention-observation";
import { buildRememberedLaterReport } from "@/lib/social-proof/remembered-later";
import { buildProductionReadinessReport } from "@/lib/observation/production-readiness";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import { buildSyncHealthReport } from "@/lib/sync/sync-health";
import { readWeeklyRetentionSnapshots } from "@/lib/validation/observation-summaries";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { FounderReviewRankedItem } from "@/types/validation-phase";
import type { ValidationOpsMetricRow, ValidationOpsReport } from "@/types/validation-ops";

function metric(id: string, label: string, value: string, detail?: string): ValidationOpsMetricRow {
  return { id, label, value, detail };
}

function ranked(id: string, label: string, detail?: string): FounderReviewRankedItem {
  return { id, label, detail };
}

/** Single founder validation ops surface — observe, don't optimize. */
export async function buildValidationOpsReport(): Promise<ValidationOpsReport> {
  const entries = getMemoryEligibleEntries();
  const [
    snapshot,
    rollout,
    syncHealth,
    production,
  ] = await Promise.all([
    buildRetentionObservationSnapshot(),
    buildRolloutGatesReport(),
    buildSyncHealthReport(),
    buildProductionReadinessReport(),
  ]);

  const loops = buildRetentionLoopReport();
  const willingness = buildWillingnessSignalsReport();
  const attachment = buildArchiveAttachmentReport(entries);
  const warnings = buildFounderWarningsReport();
  const legitimacy = buildEmotionalLegitimacyReport(entries);
  const remembered = buildRememberedLaterReport(entries);
  const weekly = readWeeklyRetentionSnapshots();

  const d7Window = snapshot.retentionWindows.find((w) => w.windowDays === 7);
  const d30Window = snapshot.retentionWindows.find((w) => w.windowDays === 30);

  const revisitRate =
    entries.length > 0
      ? Math.round(
          (loops.events.filter((e) => e.kind === "entry_revisited").length / entries.length) * 100,
        )
      : 0;

  const revisitToReflection = snapshot.automated.revisitToReflectionLinks;
  const reflectionConversion =
    loops.events.filter((e) => e.kind === "entry_revisited").length > 0
      ? Math.round(
          (revisitToReflection / loops.events.filter((e) => e.kind === "entry_revisited").length) *
            100,
        )
      : 0;

  const followupStarted = snapshot.automated.followupsStarted;
  const followupCompleted = snapshot.automated.followupsCompleted;
  const followupRate =
    followupStarted > 0 ? Math.round((followupCompleted / followupStarted) * 100) : 0;

  const legitimacyTrend = weekly.length >= 2
    ? `${weekly[weekly.length - 2].revisitToReflection} → ${weekly[weekly.length - 1].revisitToReflection} revisit→reflection`
    : `${legitimacy.scores.overall} overall`;

  return {
    generatedAt: new Date().toISOString(),
    hasData: entries.length > 0 || snapshot.participantRoster.length > 0,
    activeTesters: snapshot.participantRoster
      .filter((row) => row.participant.active)
      .map((row) => row.participant),
    retention: {
      d1: metric(
        "d1",
        "D1 retention",
        `${snapshot.automated.day1Returns}`,
        `${loops.returnIndicators.day1Count} voluntary next-day returns`,
      ),
      d7: metric(
        "d7",
        "D7 retention",
        d7Window?.eligible ? (d7Window.returnedAfterFirstUse ? "Returned" : "Quiet") : "Pending",
        `${snapshot.automated.day7Returns} D7 signals · ${d7Window?.activeReturnDays ?? 0} active days`,
      ),
      d30: metric(
        "d30",
        "D30 retention",
        d30Window?.eligible ? `${d30Window.activeReturnDays} active days` : "Pending",
        d30Window?.eligible ? "30-day window open" : "Not yet eligible",
      ),
    },
    revisit: [
      metric("revisit_rate", "Revisit rate", `${revisitRate}%`, `${loops.events.filter((e) => e.kind === "entry_revisited").length} revisits`),
      metric(
        "revisit_reflection",
        "Revisit → reflection",
        `${revisitToReflection}`,
        `${reflectionConversion}% conversion`,
      ),
      metric(
        "followup",
        "Follow-up continuation",
        `${followupCompleted}/${followupStarted}`,
        followupStarted > 0 ? `${followupRate}% completed` : "No follow-ups started",
      ),
      metric("bookmarks", "Bookmarks", `${snapshot.automated.bookmarks}`, undefined),
      metric("copied", "Copy behavior", `${snapshot.automated.copiedMoments}`, undefined),
    ],
    willingness,
    attachment,
    rollout,
    warnings,
    rememberedLater: remembered.rows.slice(0, 8).map((row) =>
      ranked(row.callbackId, row.text.slice(0, 120), `${row.kind} · score ${row.score}`),
    ),
    trustFailures: production.checks
      .filter((row) => row.status === "fail")
      .slice(0, 8)
      .map((row) => ranked(row.id, row.label, row.detail)),
    syncFailures: syncHealth.issues.slice(0, 8).map((row, index) =>
      ranked(`sync-${index}`, row.type, row.detail),
    ),
    archiveOps: [
      metric(
        "exports",
        "Archive exports",
        `${snapshot.archiveProtection.exportCount}`,
        snapshot.archiveProtection.exportUsed ? "Export used" : "None yet",
      ),
      metric(
        "backup",
        "Backup configured",
        snapshot.archiveProtection.backupConfigured ? "Yes" : "No",
        snapshot.archiveProtection.encryptedBackupConfigured ? "Encrypted backup on" : "Local only",
      ),
      metric(
        "restore",
        "Restore path",
        syncHealth.lastRestoreAt ? "Used" : "Not observed",
        syncHealth.lastRestoreAt?.slice(0, 10) ?? "—",
      ),
    ],
    emotionalLegitimacyTrend: [
      metric("overall", "Overall legitimacy", `${legitimacy.scores.overall}`, legitimacyTrend),
      metric("residue", "Emotional residue", `${legitimacy.scores.emotionalResidue}`, undefined),
      metric("overclaim", "Overclaim risk", `${legitimacy.scores.overclaimRisk}`, undefined),
      metric("genericity", "Genericity risk", `${legitimacy.scores.genericityRisk}`, undefined),
    ],
  };
}

export function downloadValidationOpsJson(report: ValidationOpsReport): void {
  if (typeof window === "undefined") return;

  const blob = new Blob([JSON.stringify(report, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "validation-ops-report.json";
  anchor.click();
  URL.revokeObjectURL(url);
}

export { rolloutStageLabel };
