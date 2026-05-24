import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildSilenceTimingDebugSnapshot } from "@/lib/refinement/silence-calibration";
import { buildRevisitSequencingReport } from "@/lib/refinement/revisit-sequencing";
import {
  findForbiddenTestimonialPhrase,
  TESTIMONIAL_FORBIDDEN_PHRASES,
} from "@/lib/social-proof/testimonial-review";
import { scanOverclaimedLines, PROOF_FORBIDDEN_PATTERNS } from "@/lib/social-proof/emotional-proof";
import { buildShareObservationReport } from "@/lib/sharing/share-observation";
import { buildMonetizationObservationReport } from "@/lib/monetization/monetization-observation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  EmotionalIntegrityReport,
  EmotionalIntegrityWarning,
  RestraintRecommendation,
  SuppressionSuggestion,
} from "@/types/emotional-integrity-layer";

const PRODUCTIVITY_RE = /\b(habit|streak|productivity|optimize|goal|daily practice|self-improvement|level up)\b/i;
const THERAPY_RE = /\b(healing journey|inner work|breakthrough|transform|best self|trauma|therapy|coach)\b/i;
const ENGAGEMENT_RE = /\b(don't miss|hurry|limited time|act now|keep going|come back tomorrow)\b/i;
const EXAGGERATION_RE = /\b(profound|life-changing|transformed|everything changed|massive shift)\b/i;
const ARTIFICIAL_RE = /\b(your journey|growth era|phase \d|unlock|potential)\b/i;

function warn(
  kind: EmotionalIntegrityWarning["kind"],
  label: string,
  detail: string,
  severity: EmotionalIntegrityWarning["severity"] = "watch",
): EmotionalIntegrityWarning {
  return { id: `ei-${kind}-${label.slice(0, 12)}`, kind, label, detail, severity };
}

function scanTextIssues(text: string, id: string): EmotionalIntegrityWarning[] {
  const issues: EmotionalIntegrityWarning[] = [];
  const lower = text.toLowerCase();

  const forbidden = findForbiddenTestimonialPhrase(text);
  if (forbidden) {
    issues.push(warn("overclaiming", "Overclaiming", `${id}: ${forbidden}`, "concern"));
  }
  if (PRODUCTIVITY_RE.test(text)) {
    issues.push(warn("productivity_leakage", "Productivity leakage", id, "concern"));
  }
  if (THERAPY_RE.test(text)) {
    issues.push(warn("therapy_coaching_drift", "Therapy/coaching drift", id, "concern"));
  }
  if (ENGAGEMENT_RE.test(text)) {
    issues.push(warn("engagement_pressure", "Engagement pressure", id, "concern"));
  }
  if (EXAGGERATION_RE.test(text)) {
    issues.push(warn("emotional_exaggeration", "Emotional exaggeration", id, "concern"));
  }
  if (ARTIFICIAL_RE.test(text)) {
    issues.push(warn("artificial_profundity", "Artificial profundity", id, "concern"));
  }
  if (text.length > 160 && !lower.includes("before") && !lower.includes("after")) {
    issues.push(warn("synthetic_callback", "Synthetic-feeling callback", id, "watch"));
  }

  return issues;
}

function repetitiveFramingWarnings(entries: JournalEntry[]): EmotionalIntegrityWarning[] {
  const report = buildCallbackQualityReviewReport(entries);
  const buckets = new Map<string, number>();

  for (const item of report.items) {
    const lower = item.text.toLowerCase();
    if (lower.includes("sound different")) buckets.set("sound_different", (buckets.get("sound_different") ?? 0) + 1);
    if (lower.includes("changed later") || lower.includes("change later")) {
      buckets.set("changed_later", (buckets.get("changed_later") ?? 0) + 1);
    }
    if (lower.includes("you sound")) buckets.set("you_sound", (buckets.get("you_sound") ?? 0) + 1);
    if (lower.includes("before things")) buckets.set("before_things", (buckets.get("before_things") ?? 0) + 1);
  }

  const warnings: EmotionalIntegrityWarning[] = [];
  for (const [pattern, count] of buckets) {
    if (count >= 3) {
      warnings.push(
        warn(
          "repetitive_framing",
          "Repetitive emotional structure",
          `${pattern.replace(/_/g, " ")} appears ${count} times`,
          count >= 5 ? "concern" : "watch",
        ),
      );
    }
  }
  return warnings;
}

/** Central emotional integrity validator — warnings, restraint, suppression. */
export function buildEmotionalIntegrityReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): EmotionalIntegrityReport {
  const callbackReport = buildCallbackQualityReviewReport(entries);
  const sequencing = buildRevisitSequencingReport();
  const silence = buildSilenceTimingDebugSnapshot();
  const sharing = buildShareObservationReport();
  const monetization = buildMonetizationObservationReport();

  const warnings: EmotionalIntegrityWarning[] = [];

  for (const row of scanOverclaimedLines(entries)) {
    warnings.push(warn("overclaiming", "Overclaimed line", row.text.slice(0, 80), "concern"));
  }

  warnings.push(...repetitiveFramingWarnings(entries));

  for (const item of callbackReport.items.slice(0, 40)) {
    warnings.push(...scanTextIssues(item.text, item.id));
    if (item.manualLabels.includes("felt_generic") || item.rewriteFlags.includes("could_apply_to_many")) {
      warnings.push(warn("synthetic_callback", "Generic callback", item.id, "watch"));
    }
  }

  for (const phrase of TESTIMONIAL_FORBIDDEN_PHRASES) {
    if (callbackReport.items.some((i) => i.text.toLowerCase().includes(phrase))) {
      warnings.push(warn("copy_drift", "Copy drift", `Forbidden phrase in callbacks: ${phrase}`, "concern"));
    }
  }

  if (sequencing.revisitFatigueActive) {
    warnings.push(
      warn("callback_fatigue", "Callback fatigue", `${sequencing.fatigueScore} revisits in fatigue window`, "concern"),
    );
  }

  if (!silence.weakNoteSuppressed && silence.ignoredCooldownActive) {
    warnings.push(warn("silence_degradation", "Silence quality degradation", "Ignored cooldown not suppressing", "watch"));
  }

  if (sharing.sharedCallbacksCount >= 3 && sharing.revisitAfterShareCount === 0) {
    warnings.push(warn("sharing_cringe_risk", "Sharing cringe risk", "Shares without authentic revisit", "watch"));
  }

  if (monetization.trustDropAfterPremium > 0) {
    warnings.push(
      warn("monetization_trust_risk", "Monetization trust risk", "Trust drop after premium exposure", "concern"),
    );
  }

  for (const pattern of PROOF_FORBIDDEN_PATTERNS) {
    if (callbackReport.items.some((i) => pattern.test(i.text))) {
      warnings.push(warn("manipulation_risk", "Manipulation risk", `Pattern in callbacks: ${pattern}`, "concern"));
    }
  }

  const unique = warnings.filter(
    (row, index, arr) => arr.findIndex((r) => r.kind === row.kind && r.detail === row.detail) === index,
  );

  const emotionalSurfaces =
    callbackReport.items.length +
    (sequencing.suppressedAdjacentCount > 0 ? 2 : 0) +
    sharing.sharedCallbacksCount;

  const emotionalDensityScore = Math.min(
    100,
    Math.round(emotionalSurfaces * 2 + unique.filter((w) => w.severity === "concern").length * 8),
  );

  const explainingTooMuch = emotionalDensityScore >= 65 || unique.filter((w) => w.kind === "repetitive_framing").length >= 2;
  const overdesigned = unique.filter((w) => w.kind === "copy_drift").length >= 2;

  const founderWarnings: string[] = [];
  if (explainingTooMuch) founderWarnings.push("The product may be explaining too much.");
  if (overdesigned) founderWarnings.push("The archive may be becoming overdesigned.");

  const restraintRecommendations: RestraintRecommendation[] = [];
  if (explainingTooMuch) {
    restraintRecommendations.push({
      id: "reduce-density",
      text: "Reduce visible emotional notes per session",
      action: "reduce",
    });
  }
  if (sequencing.revisitFatigueActive) {
    restraintRecommendations.push({
      id: "widen-spacing",
      text: "Widen revisit spacing after heavy reopen",
      action: "suppress",
    });
  }
  if (unique.some((w) => w.kind === "overclaiming")) {
    restraintRecommendations.push({
      id: "audit-overclaim",
      text: "Audit overclaimed callbacks before next surfacing",
      action: "review",
    });
  }
  restraintRecommendations.push({
    id: "bias-silence",
    text: "When uncertain, prefer silence",
    action: "silence",
  });

  const suppressionSuggestions: SuppressionSuggestion[] = callbackReport.items
    .filter(
      (item) =>
        item.cutCandidate ||
        item.survival.emotionalSurvivalScore < 22 ||
        item.manualLabels.includes("felt_generic"),
    )
    .slice(0, 12)
    .map((item) => ({
      id: `suppress-${item.id}`,
      targetId: item.id,
      text: item.text.slice(0, 120),
      reason: item.cutCandidate ? "Cut candidate" : "Low survival or generic",
    }));

  return {
    generatedAt: new Date().toISOString(),
    hasData: callbackReport.hasData,
    warnings: unique.slice(0, 24),
    restraintRecommendations,
    suppressionSuggestions,
    emotionalDensityScore,
    explainingTooMuch,
    overdesigned,
    founderWarnings,
  };
}

export function validateCallbackEmotionalIntegrity(text: string): EmotionalIntegrityWarning[] {
  return scanTextIssues(text, "inline");
}
