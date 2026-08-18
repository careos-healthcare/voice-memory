import { readLocalEvents } from "@/lib/local-analytics";
import { peekCalmComprehensionPrompt } from "@/lib/onboarding/calm-comprehension";
import { assessConfusionLevel } from "@/lib/onboarding/confusion-signals";
import { peekFirstAhaCallback } from "@/lib/onboarding/first-aha-callback";
import {
  buildFirstSessionFlowSteps,
  firstSessionDropOffPoints,
  getFirstSessionElapsedMs,
  hoursSinceFirstSession,
  isWithinFirstTwoMinutes,
} from "@/lib/onboarding/first-session-flow";
import { countOnboardingClarityEvents } from "@/lib/onboarding/onboarding-observation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { OnboardingClarityDebugReport } from "@/types/onboarding-clarity";

function firstRevisitDelayHours(): number | null {
  const events = readLocalEvents();
  const reflection = events.find((e) => e.name === "first_reflection_created");
  const revisit =
    events.find((e) => e.name === "revisit_opened") ??
    events.find((e) => e.name === "first_session_old_reflection_opened");
  if (!reflection?.at || !revisit?.at) return null;
  return (new Date(revisit.at).getTime() - new Date(reflection.at).getTime()) / (1000 * 60 * 60);
}

function timeToMeaningfulMomentMs(): number | null {
  const events = readLocalEvents();
  const anchor = events.find(
    (e) =>
      e.name === "first_reflection_created" ||
      e.name === "onboarding_flow_step_completed",
  );
  const payoff = events.find(
    (e) =>
      e.name === "first_aha_moment" ||
      e.name === "revisit_reward_seen" ||
      e.name === "first_callback_landed" ||
      e.name === "first_revisit_completed",
  );
  if (!anchor?.at || !payoff?.at) return null;
  return new Date(payoff.at).getTime() - new Date(anchor.at).getTime();
}

function revisitConversionLabel(): string {
  const events = readLocalEvents();
  const opened = events.filter((e) => e.name === "revisit_opened").length;
  const old = events.filter((e) => e.name === "first_session_old_reflection_opened").length;
  const aha = events.filter((e) => e.name === "first_aha_moment").length;
  if (opened + old === 0) return "No revisit opens yet";
  if (aha > 0) return `${opened + old} revisit(s) · first aha surfaced`;
  return `${opened + old} revisit(s) · no aha yet`;
}

function overwhelmingSurfaces(): string[] {
  const surfaces: string[] = [];
  const events = readLocalEvents();
  if (events.some((e) => e.name === "overwhelmed_exit")) {
    surfaces.push("User exited while overwhelmed");
  }
  const rapid = events.filter((e) => e.name === "rapid_navigation").length;
  if (rapid >= 2) surfaces.push("Rapid navigation bursts");
  const ignored = events.filter((e) => e.name === "comprehension_prompt_ignored").length;
  if (ignored >= 2) surfaces.push("Comprehension prompts ignored repeatedly");
  return surfaces;
}

function ignoredCopyCount(): number {
  return readLocalEvents().filter((e) => e.name === "comprehension_prompt_ignored").length;
}

export function buildOnboardingClarityDebugReport(): OnboardingClarityDebugReport {
  const entries = getMemoryEligibleEntries();
  const confusion = assessConfusionLevel();

  return {
    generatedAt: new Date().toISOString(),
    withinTwoMinutes: isWithinFirstTwoMinutes(),
    flowSteps: buildFirstSessionFlowSteps(),
    dropOffPoints: firstSessionDropOffPoints(),
    confusionLevel: confusion.level,
    confusionSignals: confusion.signals,
    ahaTimingHours: hoursSinceFirstSession(),
    firstRevisitDelayHours: firstRevisitDelayHours(),
    revisitConversion: revisitConversionLabel(),
    timeToMeaningfulMomentMs: timeToMeaningfulMomentMs(),
    overwhelmingSurfaces: overwhelmingSurfaces(),
    ignoredCopyCount: ignoredCopyCount(),
    instrumentation: countOnboardingClarityEvents(),
    activeComprehension: peekCalmComprehensionPrompt(),
    activeFirstAha: peekFirstAhaCallback(entries),
  };
}

export function onboardingClaritySummaryLine(): string {
  const elapsed = getFirstSessionElapsedMs();
  const mins = Math.round(elapsed / 60000);
  return `First session ${mins}m elapsed · ${isWithinFirstTwoMinutes() ? "in" : "past"} 2-minute window`;
}
