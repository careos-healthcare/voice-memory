import { trackLocalEvent } from "@/lib/local-analytics";

const SHOWN_KEY = "voicememory_onboarding_trust_shown";
const MEANINGFUL_KEY = "voicememory_onboarding_trust_eligible";

export const ONBOARDING_TRUST_LINES = [
  "Older reflections sometimes land differently later.",
  "You may hear yourself differently with time.",
  "Not everything needs to make sense immediately.",
] as const;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function hasShownOnboardingTrustLine(): boolean {
  if (!isBrowser()) return true;
  return localStorage.getItem(SHOWN_KEY) === "1";
}

export function markOnboardingTrustShown(): void {
  if (!isBrowser()) return;
  localStorage.setItem(SHOWN_KEY, "1");
  trackLocalEvent("onboarding_trust_line_shown");
}

export function markMeaningfulRevisitEligible(): void {
  if (!isBrowser()) return;
  localStorage.setItem(MEANINGFUL_KEY, "1");
}

export function isMeaningfulRevisitEligible(): boolean {
  if (!isBrowser()) return false;
  return localStorage.getItem(MEANINGFUL_KEY) === "1";
}

export function pickOnboardingTrustLine(): string {
  const index = Math.floor(Math.random() * ONBOARDING_TRUST_LINES.length);
  return ONBOARDING_TRUST_LINES[index];
}

export function resolveOnboardingTrustAfterRevisit(input: {
  isRevisit: boolean;
  hasRevisitReward: boolean;
  hasThenVsNow: boolean;
  reopenPayoffScore: number | null;
  audioReplayed?: boolean;
}): { showLine: boolean; text: string | null } {
  if (!input.isRevisit || hasShownOnboardingTrustLine()) {
    return { showLine: false, text: null };
  }

  const meaningful =
    input.hasRevisitReward ||
    input.hasThenVsNow ||
    input.audioReplayed ||
    (input.reopenPayoffScore ?? 0) >= 50;

  if (!meaningful) {
    return { showLine: false, text: null };
  }

  markMeaningfulRevisitEligible();
  return { showLine: true, text: pickOnboardingTrustLine() };
}
