import { buildArchiveAttachmentReport } from "@/lib/research/archive-attachment";
import { buildEmotionalLegitimacyReport } from "@/lib/debug/emotional-legitimacy-review";
import { buildRetentionObservationSnapshot } from "@/lib/research/retention-observation";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import { buildSyncHealthReport } from "@/lib/sync/sync-health";
import { buildProductionReadinessReport } from "@/lib/observation/production-readiness";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  RolloutGateCheck,
  RolloutGatesReport,
  RolloutStage,
} from "@/types/validation-ops";

const STAGE_ORDER: RolloutStage[] = [
  "prototype",
  "emotional_validation",
  "attachment_validation",
  "permanence_validation",
  "monetization_ready",
];

function stageIndex(stage: RolloutStage): number {
  return STAGE_ORDER.indexOf(stage);
}

function check(id: string, label: string, ok: boolean, detail: string): RolloutGateCheck {
  return { id, label, ok, detail };
}

function resolveRecommendedStage(checks: RolloutGateCheck[]): RolloutStage {
  const entries = getMemoryEligibleEntries().length;
  if (entries < 4) return "prototype";

  const emotionalOk = checks.filter((c) => c.id.startsWith("emotional_")).every((c) => c.ok);
  const attachmentOk = checks.filter((c) => c.id.startsWith("attachment_")).every((c) => c.ok);
  const permanenceOk = checks.filter((c) => c.id.startsWith("permanence_")).every((c) => c.ok);
  const monetizationOk = checks.filter((c) => c.id.startsWith("monetization_")).every((c) => c.ok);

  if (monetizationOk && permanenceOk && attachmentOk && emotionalOk) return "monetization_ready";
  if (permanenceOk && attachmentOk && emotionalOk) return "permanence_validation";
  if (attachmentOk && emotionalOk) return "attachment_validation";
  if (emotionalOk) return "emotional_validation";
  return "prototype";
}

/** Gate rollout stages based on retention, attachment, trust, and legitimacy. */
export async function buildRolloutGatesReport(): Promise<RolloutGatesReport> {
  const entries = getMemoryEligibleEntries();
  const snapshot = await buildRetentionObservationSnapshot();
  const loops = buildRetentionLoopReport();
  const attachment = buildArchiveAttachmentReport(entries);
  const legitimacy = buildEmotionalLegitimacyReport(entries);
  const [syncHealth, production] = await Promise.all([
    buildSyncHealthReport(),
    buildProductionReadinessReport(),
  ]);

  const d7Window = snapshot.retentionWindows.find((w) => w.windowDays === 7);
  const d30Window = snapshot.retentionWindows.find((w) => w.windowDays === 30);

  const checks: RolloutGateCheck[] = [
    check(
      "retention_d7",
      "D7 return signal",
      loops.returnIndicators.day7Count > 0 || Boolean(d7Window?.returnedAfterFirstUse),
      `${loops.returnIndicators.day7Count} D7 returns · ${d7Window?.activeReturnDays ?? 0} active days in week 1`,
    ),
    check(
      "retention_d30",
      "D30 observation window",
      Boolean(d30Window?.eligible),
      d30Window?.eligible ? `${d30Window.activeReturnDays} active days in 30d window` : "Not yet 30 days",
    ),
    check(
      "revisit_depth",
      "Revisit depth",
      loops.revisitsCausingReflections.length >= 1 || loops.notesCausingRevisits.length >= 2,
      `${loops.revisitsCausingReflections.length} revisit→reflection · ${loops.notesCausingRevisits.length} notes causing revisits`,
    ),
    check(
      "attachment_score",
      "Archive attachment",
      attachment.attachmentScore >= 50,
      `Attachment score ${attachment.attachmentScore} · ${attachment.signals.length} signals`,
    ),
    check(
      "attachment_irreplaceable",
      "Personally irreplaceable",
      attachment.irreplaceable,
      attachment.irreplaceable ? "Multiple durable attachment signals" : "Still forming attachment",
    ),
    check(
      "trust_sync",
      "Sync reliability",
      syncHealth.issues.filter((i) => i.type === "sync_error").length === 0,
      `${syncHealth.issues.length} sync issue(s)`,
    ),
    check(
      "trust_production",
      "Trust stability",
      production.checks.filter((c) => c.status === "fail").length <= 1,
      `${production.checks.filter((c) => c.status === "fail").length} production failure(s)`,
    ),
    check(
      "emotional_legitimacy",
      "Emotional legitimacy",
      legitimacy.scores.overall >= 55,
      `Overall legitimacy ${legitimacy.scores.overall}`,
    ),
    check(
      "emotional_overclaim",
      "Overclaim risk contained",
      legitimacy.scores.overclaimRisk <= 45,
      `Overclaim risk ${legitimacy.scores.overclaimRisk}`,
    ),
    check(
      "permanence_export",
      "Archive export/restore path",
      snapshot.archiveProtection.exportUsed || snapshot.archiveProtection.backupConfigured,
      snapshot.archiveProtection.exportCount > 0
        ? `${snapshot.archiveProtection.exportCount} export(s)`
        : "No export yet",
    ),
    check(
      "monetization_wtp",
      "Willingness signals present",
      snapshot.emotionalResidue.some((n) => n.wouldPay === "yes" || n.wouldPay === "maybe"),
      `${snapshot.emotionalResidue.filter((n) => n.wouldPay).length} manual WTP note(s)`,
    ),
  ];

  const recommendedStage = resolveRecommendedStage(checks);
  const weakCount = checks.filter((c) => !c.ok).length;
  const observeLonger = weakCount >= 4 || recommendedStage === "prototype";
  const observeMessage = observeLonger ? "Observe longer before scaling." : null;

  const stageProgress = Object.fromEntries(
    STAGE_ORDER.map((stage) => [stage, stageIndex(stage) <= stageIndex(recommendedStage)]),
  ) as Record<RolloutStage, boolean>;

  return {
    generatedAt: new Date().toISOString(),
    currentStage: recommendedStage,
    recommendedStage,
    observeLonger,
    observeMessage,
    checks,
    stageProgress,
  };
}

export function rolloutStageLabel(stage: RolloutStage): string {
  const labels: Record<RolloutStage, string> = {
    prototype: "Prototype",
    emotional_validation: "Emotional validation",
    attachment_validation: "Attachment validation",
    permanence_validation: "Permanence validation",
    monetization_ready: "Monetization-ready",
  };
  return labels[stage];
}
