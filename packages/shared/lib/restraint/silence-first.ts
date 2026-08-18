import { buildSacrednessReport } from "@/lib/restraint/sacredness";
import { buildSilenceTimingDebugSnapshot } from "@/lib/refinement/silence-calibration";
import { buildRevisitSequencingReport } from "@/lib/refinement/revisit-sequencing";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { SilenceFirstPolicy } from "@/types/sacredness-layer";

const CHANGED_RE = /\b(changed|change) later\b/i;
const IDENTITY_RE = /\b(you sound|sound different|your voice|who you are)\b/i;
const INTERPRETIVE_RE = /\b(this means|this shows|you are becoming|phase|era|journey)\b/i;

/** Silence-first mode — dramatically reduce resurfacing when saturated. */
export function getSilenceFirstPolicy(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): SilenceFirstPolicy {
  const sacredness = buildSacrednessReport(entries);
  const silence = buildSilenceTimingDebugSnapshot();
  const sequencing = buildRevisitSequencingReport();

  const reasons: string[] = [];
  if (sacredness.inflationWarnings.some((w) => w.kind === "saturation")) {
    reasons.push("emotional_saturation");
  }
  if (silence.consecutiveIgnored >= 2 || silence.ignoredCooldownActive) {
    reasons.push("callbacks_ignored");
  }
  if (sequencing.revisitFatigueActive) reasons.push("revisit_fatigue");
  if (sacredness.inflationWarnings.some((w) => w.kind === "density_inflation")) {
    reasons.push("archive_density_high");
  }
  if (sequencing.suppressedAdjacentCount >= 3) reasons.push("continuity_overactive");

  const active =
    reasons.length >= 2 ||
    sacredness.silencePreferred ||
    (sequencing.revisitFatigueActive && silence.weakNoteSuppressed);

  let spacingMultiplier = 1;
  if (active) spacingMultiplier = 2.5;
  if (sequencing.revisitFatigueActive) spacingMultiplier = Math.max(spacingMultiplier, 3);
  if (sacredness.emotionallyCrowded) spacingMultiplier = Math.max(spacingMultiplier, 2);

  return {
    active,
    reasons,
    reduceResurfacing: active,
    preferEmptyStates: active,
    suppressInterpretation: active,
    suppressChanged: active,
    suppressIdentity: active || sequencing.revisitFatigueActive,
    delayFollowups: active,
    spacingMultiplier,
  };
}

export function isSilenceFirstModeActive(entries?: JournalEntry[]): boolean {
  return getSilenceFirstPolicy(entries).active;
}

export function shouldSuppressInSilenceFirst(text: string, entries?: JournalEntry[]): boolean {
  const policy = getSilenceFirstPolicy(entries);
  if (!policy.active) return false;
  if (policy.suppressChanged && CHANGED_RE.test(text)) return true;
  if (policy.suppressIdentity && IDENTITY_RE.test(text)) return true;
  if (policy.suppressInterpretation && INTERPRETIVE_RE.test(text)) return true;
  return false;
}

export function silenceFirstSpacingDays(baseDays: number, entries?: JournalEntry[]): number {
  const policy = getSilenceFirstPolicy(entries);
  return Math.round(baseDays * policy.spacingMultiplier);
}
