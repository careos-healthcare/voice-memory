import { buildArchiveAttachmentReport } from "@/lib/research/archive-attachment";
import { readWillingnessFounderLabels } from "@/lib/research/willingness-signals";
import { getOrCreateParticipantId } from "@/lib/research/retention-observation";
import { detectArchiveValueMoments } from "@/lib/monetization/archive-value";
import { buildMonetizationObservationReport } from "@/lib/monetization/monetization-observation";
import { evaluateMonetizationRestraint, suppressionReasonLabel } from "@/lib/monetization/monetization-restraint";
import { getPremiumState, premiumStateLabel } from "@/lib/monetization/premium-state";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveValueReviewReport, PremiumSurface } from "@/types/monetization-validation";

function trustRiskMoments() {
  return detectArchiveValueMoments().filter(
    (row) => row.kind === "would_miss_archive" || row.strength >= 80,
  );
}

function safestMoments() {
  return detectArchiveValueMoments().filter(
    (row) =>
      row.kind === "export_usage" ||
      row.kind === "encrypted_backup" ||
      row.kind === "restore_after_reinstall",
  );
}

/** Founder archive-value review — debug only. */
export async function buildArchiveValueReviewReport(): Promise<ArchiveValueReviewReport> {
  const entries = getMemoryEligibleEntries();
  const attachment = buildArchiveAttachmentReport(entries);
  const observation = buildMonetizationObservationReport();
  const restraint = await evaluateMonetizationRestraint("archive");
  const surfaces: PremiumSurface[] = ["account", "archive", "restore", "export"];

  const suppressionReasons = (
    await Promise.all(surfaces.map((surface) => evaluateMonetizationRestraint(surface)))
  ).flatMap((report) => report.suppressionReasons);

  const uniqueSuppression = [...new Set(suppressionReasons)];

  const wtpEvolution = [
    ...readWillingnessFounderLabels(getOrCreateParticipantId()).slice(0, 6).map((row) => ({
      at: row.createdAt.slice(0, 10),
      label: row.label,
      detail: row.note ?? "Founder label",
    })),
    ...detectArchiveValueMoments()
      .slice(0, 4)
      .map((row) => ({
        at: row.at?.slice(0, 10) ?? "—",
        label: row.kind,
        detail: row.detail,
      })),
  ];

  return {
    generatedAt: new Date().toISOString(),
    hasData: attachment.hasData || observation.hasData,
    attachmentSignals: attachment.signals.map((row) => ({
      id: row.id,
      label: row.label,
      detail: row.detail,
      strength: row.strength,
    })),
    safestMoments: safestMoments().slice(0, 6),
    trustRiskMoments: trustRiskMoments().slice(0, 6),
    suppressionReasons: uniqueSuppression,
    archiveProtectionInterest: attachment.attachmentScore,
    premiumState: getPremiumState(),
    wtpEvolution,
    legitimacyBeforeExposure: observation.legitimacyBeforeExposure,
    legitimacyAfterExposure: observation.legitimacyAfterExposure,
    observation,
    restraint,
  };
}

export function downloadArchiveValueReviewJson(
  report: ArchiveValueReviewReport,
): void {
  if (typeof window === "undefined") return;

  const blob = new Blob([JSON.stringify(report, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "archive-value-review.json";
  anchor.click();
  URL.revokeObjectURL(url);
}

export { premiumStateLabel, suppressionReasonLabel };
