import { buildProductionReadinessReport } from "@/lib/observation/production-readiness";
import { buildMoatReviewReport } from "@/lib/observation/moat-review";
import { readLastStressTestReport } from "@/lib/reliability/stress-tests";
import { buildMonetizationObservationReport } from "@/lib/monetization/monetization-observation";
import { buildArchiveOwnershipReport } from "@/lib/archive/archive-ownership";
import { buildArchiveAttachmentReport } from "@/lib/research/archive-attachment";
import { hasPreRestoreBackup } from "@/lib/sync/sync-health";
import { readLastBackupAt, readLastSyncError } from "@/lib/sync/status-storage";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import { getAllEntries } from "@/lib/storage";
import type {
  MonetizationGateVerdict,
  MonetizationReadinessReport,
  ReadinessCheck,
  ReadinessCheckStatus,
} from "@/types/observation-workflow";

function check(status: ReadinessCheckStatus, id: string, label: string, detail: string): ReadinessCheck {
  return { id, label, status, detail };
}

/** Monetization gate — no Stripe, no pricing prompts. Debug only. */
export async function buildMonetizationReadinessReport(): Promise<MonetizationReadinessReport> {
  const moatReview = buildMoatReviewReport();
  const production = await buildProductionReadinessReport();
  const loops = buildRetentionLoopReport();
  const stress = readLastStressTestReport();
  const ownership = await buildArchiveOwnershipReport();
  const entries = getAllEntries();

  const retentionChecks: ReadinessCheck[] = [
    check(
      moatReview.metrics.find((row) => row.id === "old_entry_revisit")?.met ? "pass" : "fail",
      "retention_revisit",
      "Old-entry revisit rate",
      moatReview.metrics.find((row) => row.id === "old_entry_revisit")?.countHint ?? "—",
    ),
    check(
      moatReview.metrics.find((row) => row.id === "revisit_to_reflection")?.met ? "pass" : "fail",
      "retention_reflection",
      "Revisit → new reflection",
      moatReview.metrics.find((row) => row.id === "revisit_to_reflection")?.countHint ?? "—",
    ),
    check(
      loops.returnIndicators.day7Count > 0 ? "pass" : "warn",
      "retention_d7",
      "Day-7 voluntary return",
      `${loops.returnIndicators.day7Count} recorded`,
    ),
  ];

  const moatChecks: ReadinessCheck[] = moatReview.metrics
    .filter((row) => row.targetValue > 0)
    .map((row) =>
      check(
        row.met ? "pass" : "fail",
        `moat_${row.id}`,
        row.label,
        `${row.current} vs target ${row.target}`,
      ),
    );

  const trustChecks: ReadinessCheck[] = [
    check(
      stress?.allPassed ? "pass" : stress ? "fail" : "warn",
      "trust_stress",
      "Archive stress tests",
      stress ? (stress.allPassed ? "All passed" : `${stress.failed} failed`) : "Not run",
    ),
    check(
      production.checks.find((row) => row.id === "audio_save")?.status === "pass" ? "pass" : "warn",
      "trust_audio",
      "Audio integrity",
      production.checks.find((row) => row.id === "audio_save")?.detail ?? "—",
    ),
    check(
      hasPreRestoreBackup() ? "pass" : "warn",
      "trust_restore_rollback",
      "Restore rollback snapshot",
      hasPreRestoreBackup() ? "Available" : "Not captured yet",
    ),
  ];

  const syncError = readLastSyncError();
  const syncChecks: ReadinessCheck[] = [
    check(
      syncError ? "fail" : readLastBackupAt() ? "pass" : "warn",
      "sync_backup",
      "Encrypted backup",
      syncError ? syncError.slice(0, 100) : readLastBackupAt() ?? "No backup timestamp",
    ),
    check(
      production.checks.find((row) => row.id === "encrypted_sync")?.status === "fail"
        ? "fail"
        : "pass",
      "sync_health",
      "Sync reliability",
      production.checks.find((row) => row.id === "encrypted_sync")?.detail ?? "—",
    ),
  ];

  const archiveChecks: ReadinessCheck[] = [
    check(
      ownership.localExportUsed ? "pass" : "warn",
      "archive_export",
      "Archive export path",
      ownership.localExportUsed ? "Export used" : "Export not verified on device",
    ),
    check(
      ownership.backupConfigured ? "pass" : "warn",
      "archive_backup",
      "Archive backup configured",
      ownership.backupConfigured ? "Yes" : "Not configured",
    ),
    check(
      entries.length >= 8 ? "pass" : "warn",
      "archive_depth",
      "Archive depth for observation",
      `${entries.length} reflections`,
    ),
  ];

  const allGroups = [...retentionChecks, ...moatChecks, ...trustChecks, ...syncChecks, ...archiveChecks];
  const failures = allGroups.filter((row) => row.status === "fail").length;
  const allMet = failures === 0 && moatReview.metCount >= Math.ceil(moatReview.totalCount * 0.8);

  const verdict: MonetizationGateVerdict = allMet ? "test_carefully" : "blocked";
  const headline =
    verdict === "blocked"
      ? "Do not monetize yet."
      : "Payment can be tested carefully.";

  return {
    generatedAt: new Date().toISOString(),
    verdict,
    headline,
    retentionChecks,
    moatChecks,
    trustChecks,
    syncChecks,
    archiveChecks,
    stripeRecommendation:
      verdict === "blocked"
        ? "Keep Stripe blocked — thresholds and trust checks not met."
        : "Stripe may be considered for a small closed test — no public pricing prompts yet.",
    allMet,
    softMonetization: buildMonetizationObservationReport(),
    archiveProtectionInterest: buildArchiveAttachmentReport(entries).attachmentScore,
  };
}
