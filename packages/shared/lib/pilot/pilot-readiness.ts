import { buildArchiveMaturityReport } from "@/lib/debug/archive-maturity-review";
import { buildEmotionalLegitimacyReport } from "@/lib/debug/emotional-legitimacy-review";
import { buildArchiveAttachmentReport } from "@/lib/research/archive-attachment";
import { buildWillingnessSignalsReport } from "@/lib/research/willingness-signals";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import { buildSyncHealthReport } from "@/lib/sync/sync-health";
import { buildProductionReadinessReport } from "@/lib/observation/production-readiness";
import { buildMonetizationObservationReport } from "@/lib/monetization/monetization-observation";
import { getPremiumState } from "@/lib/monetization/premium-state";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { PilotReadinessCheck, PilotReadinessReport } from "@/types/pilot-system";

function check(id: string, label: string, ok: boolean, detail: string): PilotReadinessCheck {
  return { id, label, ok, detail };
}

/** Founder readiness gate — keep observing before charging. */
export async function buildPilotReadinessReport(): Promise<PilotReadinessReport> {
  const entries = getMemoryEligibleEntries();
  const attachment = buildArchiveAttachmentReport(entries);
  const legitimacy = buildEmotionalLegitimacyReport(entries);
  const maturity = buildArchiveMaturityReport(entries);
  const loops = buildRetentionLoopReport();
  const willingness = buildWillingnessSignalsReport();
  const observation = buildMonetizationObservationReport();
  const [syncHealth, production] = await Promise.all([
    buildSyncHealthReport(),
    buildProductionReadinessReport(),
  ]);

  const checks: PilotReadinessCheck[] = [
    check(
      "attachment_quality",
      "Attachment quality",
      attachment.attachmentScore >= 50,
      `Score ${attachment.attachmentScore}`,
    ),
    check(
      "trust_stability",
      "Trust stability",
      production.failed <= 1,
      `${production.failed} production failure(s)`,
    ),
    check(
      "sync_reliability",
      "Sync reliability",
      syncHealth.issues.filter((i) => i.type === "sync_error").length === 0,
      `${syncHealth.issues.length} sync issue(s)`,
    ),
    check(
      "archive_maturity",
      "Archive maturity",
      maturity.hasData && entries.length >= 8,
      `${entries.length} entries · density ${maturity.archiveDepth.densityScore}`,
    ),
    check(
      "revisit_durability",
      "Revisit durability",
      loops.revisitsCausingReflections.length >= 1 || loops.notesCausingRevisits.length >= 2,
      `${loops.revisitsCausingReflections.length} revisit→reflection links`,
    ),
    check(
      "emotional_legitimacy",
      "Emotional legitimacy",
      legitimacy.scores.overall >= 55,
      `Overall ${legitimacy.scores.overall}`,
    ),
    check(
      "payment_readiness",
      "Payment readiness signals",
      willingness.summary.wouldPay > 0 ||
        willingness.summary.maybe > 0 ||
        getPremiumState() === "willing_to_pay_observed",
      `${willingness.summary.wouldPay} would pay · ${willingness.summary.maybe} maybe`,
    ),
  ];

  const failed = checks.filter((c) => !c.ok).length;
  const ready = failed <= 2 && checks.filter((c) => c.id === "emotional_legitimacy")[0]?.ok;
  const observeMessage = ready ? null : "Keep observing before charging.";

  const paymentReadinessConfidence = Math.min(
    100,
    Math.round(
      (attachment.attachmentScore * 0.25 +
        legitimacy.scores.overall * 0.25 +
        (observation.premiumLinesSeen > 0 ? 15 : 0) +
        willingness.summary.behavioralCount * 5 +
        (checks.find((c) => c.id === "payment_readiness")?.ok ? 20 : 0)) -
        failed * 12,
    ),
  );

  return {
    generatedAt: new Date().toISOString(),
    ready: Boolean(ready),
    observeMessage,
    paymentReadinessConfidence,
    checks,
  };
}
