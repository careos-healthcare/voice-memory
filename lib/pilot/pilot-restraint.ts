import { buildEmotionalLegitimacyReport } from "@/lib/debug/emotional-legitimacy-review";
import { buildArchiveAttachmentReport } from "@/lib/research/archive-attachment";
import { buildRevisitSequencingReport } from "@/lib/refinement/revisit-sequencing";
import { buildProductionReadinessReport } from "@/lib/observation/production-readiness";
import { readLastSyncError } from "@/lib/sync/status-storage";
import { buildPilotAccessReport, PILOT_MAX_USERS } from "@/lib/pilot/pilot-access";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { PilotRestraintReport, PilotSuppressionReason } from "@/types/pilot-system";

const PILOT_IGNORED_KEY = "voicememory_pilot_ignored_until";
const PREMIUM_IGNORED_KEY = "voicememory_premium_ignored_until";
const LEGITIMACY_MIN = 50;
const ATTACHMENT_MIN = 45;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function pilotRecentlyIgnored(): boolean {
  if (!isBrowser()) return false;
  for (const key of [PILOT_IGNORED_KEY, PREMIUM_IGNORED_KEY]) {
    const raw = localStorage.getItem(key);
    if (raw && Date.now() < Number(raw)) return true;
  }
  return false;
}

export function dismissPilotExposure(cooldownDays = 21): void {
  if (!isBrowser()) return;
  localStorage.setItem(PILOT_IGNORED_KEY, String(Date.now() + cooldownDays * 86400000));
}

function isLegitimacyWeak(): boolean {
  const report = buildEmotionalLegitimacyReport(getMemoryEligibleEntries());
  return report.scores.overall < LEGITIMACY_MIN;
}

function isAttachmentWeak(): boolean {
  const attachment = buildArchiveAttachmentReport(getMemoryEligibleEntries());
  return attachment.attachmentScore < ATTACHMENT_MIN;
}

async function isTrustRiskElevated(): Promise<boolean> {
  const production = await buildProductionReadinessReport();
  return production.failed >= 2 || Boolean(readLastSyncError());
}

/** Suppress pilot exposure when archive/trust signals are not ready. */
export async function evaluatePilotRestraint(): Promise<PilotRestraintReport> {
  const reasons: PilotSuppressionReason[] = [];
  const sequencing = buildRevisitSequencingReport();
  const access = buildPilotAccessReport();

  if (isLegitimacyWeak()) reasons.push("legitimacy_weak");
  if (sequencing.revisitFatigueActive) reasons.push("revisit_fatigue");
  if (await isTrustRiskElevated()) reasons.push("trust_risk_elevated");
  if (pilotRecentlyIgnored()) reasons.push("archive_value_ignored");
  if (isAttachmentWeak()) reasons.push("attachment_weak");
  if (access.approvedCount + access.invitedCount >= PILOT_MAX_USERS) {
    reasons.push("capacity_full");
  }

  return {
    generatedAt: new Date().toISOString(),
    allowed: reasons.length === 0,
    suppressionReasons: reasons,
  };
}

export async function shouldShowPilotExposure(): Promise<boolean> {
  const report = await evaluatePilotRestraint();
  return report.allowed;
}

export function pilotSuppressionLabel(reason: PilotSuppressionReason): string {
  const labels: Record<PilotSuppressionReason, string> = {
    legitimacy_weak: "Emotional legitimacy is weak",
    revisit_fatigue: "Revisit fatigue is rising",
    trust_risk_elevated: "Trust risk is elevated",
    archive_value_ignored: "User recently ignored archive value copy",
    attachment_weak: "Archive attachment is weak",
    capacity_full: "Pilot capacity reached (20 users)",
  };
  return labels[reason];
}
