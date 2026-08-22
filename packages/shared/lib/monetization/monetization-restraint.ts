import { buildEmotionalLegitimacyReport } from "@/lib/debug/emotional-legitimacy-review";
import { readLocalEvents } from "@/lib/local-analytics";
import { buildRevisitSequencingReport } from "@/lib/refinement/revisit-sequencing";
import { buildProductionReadinessReport } from "@/lib/observation/production-readiness";
import { readLastSyncError } from "@/lib/sync/status-storage";
import { detectArchiveValueMoments } from "@/lib/monetization/archive-value";
import { getPremiumState } from "@/lib/monetization/premium-state";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  MonetizationRestraintReport,
  MonetizationSuppressionReason,
  PremiumSurface,
} from "@/types/monetization-validation";

const SESSION_KEY = "voicememory_premium_mention_session";
const IGNORED_KEY = "voicememory_premium_ignored_until";
const MS_PER_HOUR = 1000 * 60 * 60;
const LEGITIMACY_MIN = 50;

const ALLOWED_SURFACES = new Set<PremiumSurface>(["account", "archive", "restore", "export"]);

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function sessionMentionUsed(): boolean {
  if (!isBrowser()) return false;
  return sessionStorage.getItem(SESSION_KEY) === "1";
}

export function markPremiumMentionShown(): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(SESSION_KEY, "1");
}

export function dismissPremiumLine(cooldownDays = 14): void {
  if (!isBrowser()) return;
  const until = Date.now() + cooldownDays * 86400000;
  localStorage.setItem(IGNORED_KEY, String(until));
}

function premiumRecentlyIgnored(): boolean {
  if (!isBrowser()) return false;
  const raw = localStorage.getItem(IGNORED_KEY);
  if (!raw) return false;
  return Date.now() < Number(raw);
}

function isEmotionalMomentActive(): boolean {
  if (!isBrowser()) return false;
  try {
    const raw = localStorage.getItem("voicememory_emotional_timing");
    if (!raw) return false;
    const parsed = JSON.parse(raw) as {
      lastEmotionalAt?: number;
      revisitBoostUntil?: number;
      followupBoostUntil?: number;
    };
    const hoursSince = parsed.lastEmotionalAt
      ? (Date.now() - parsed.lastEmotionalAt) / MS_PER_HOUR
      : 999;
    return (
      hoursSince < 3 ||
      Date.now() < (parsed.revisitBoostUntil ?? 0) ||
      Date.now() < (parsed.followupBoostUntil ?? 0)
    );
  } catch {
    return false;
  }
}

function isRevisitPayoffActive(): boolean {
  const events = readLocalEvents();
  return events.some((event) => {
    if (event.name !== "revisit_reward_seen" && event.name !== "revisit_reward_followup") {
      return false;
    }
    return Date.now() - new Date(event.at).getTime() < 2 * MS_PER_HOUR;
  });
}

async function isTrustRiskElevated(): Promise<boolean> {
  const production = await buildProductionReadinessReport();
  return production.failed >= 2 || Boolean(readLastSyncError());
}

function isLegitimacyWeak(): boolean {
  const report = buildEmotionalLegitimacyReport(getMemoryEligibleEntries());
  return report.scores.overall < LEGITIMACY_MIN;
}

function hasSufficientAttachment(): boolean {
  const state = getPremiumState();
  if (state !== "free") return true;
  return detectArchiveValueMoments().length >= 1;
}

/** Trust-protection guardrails for soft monetization surfaces. */
export async function evaluateMonetizationRestraint(
  surface: PremiumSurface,
): Promise<MonetizationRestraintReport> {
  const reasons: MonetizationSuppressionReason[] = [];

  if (!ALLOWED_SURFACES.has(surface)) {
    reasons.push("surface_not_allowed");
  }
  if (sessionMentionUsed()) {
    reasons.push("session_cap_reached");
  }
  if (premiumRecentlyIgnored()) {
    reasons.push("premium_recently_ignored");
  }
  if (isEmotionalMomentActive()) {
    reasons.push("emotional_moment_active");
  }
  if (isRevisitPayoffActive()) {
    reasons.push("revisit_payoff_active");
  }
  if (isLegitimacyWeak()) {
    reasons.push("legitimacy_weak");
  }
  if (!hasSufficientAttachment()) {
    reasons.push("insufficient_attachment");
  }
  if (await isTrustRiskElevated()) {
    reasons.push("trust_risk_elevated");
  }

  const sequencing = buildRevisitSequencingReport();
  if (sequencing.revisitFatigueActive) {
    reasons.push("emotional_moment_active");
  }

  const unique = [...new Set(reasons)];

  return {
    generatedAt: new Date().toISOString(),
    allowed: unique.length === 0,
    suppressionReasons: unique,
  };
}

export async function shouldShowPremiumSurface(surface: PremiumSurface): Promise<boolean> {
  const restraint = await evaluateMonetizationRestraint(surface);
  return restraint.allowed;
}

export function suppressionReasonLabel(reason: MonetizationSuppressionReason): string {
  const labels: Record<MonetizationSuppressionReason, string> = {
    emotional_moment_active: "Emotional moment just occurred",
    revisit_payoff_active: "Revisit payoff is active",
    premium_recently_ignored: "User recently ignored premium copy",
    trust_risk_elevated: "Trust risk is elevated",
    legitimacy_weak: "Emotional legitimacy score is weak",
    session_cap_reached: "One premium mention per session",
    surface_not_allowed: "Surface not allowed",
    insufficient_attachment: "Insufficient archive attachment",
  };
  return labels[reason];
}
