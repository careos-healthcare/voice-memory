import { countLocalEvents, hasLocalEvent, trackLocalEvent } from "@/lib/local-analytics";

export const ONBOARDING_CLARITY_EVENTS = {
  onboardingCompleted: "onboarding_completed",
  firstAhaMoment: "first_aha_moment",
  callbackSurprise: "callback_surprise",
  confusionDetected: "confusion_detected",
  firstRevisitDelay: "first_revisit_delay",
  archiveUnderstood: "archive_understood",
  overwhelmedExit: "overwhelmed_exit",
  flowStepCompleted: "onboarding_flow_step_completed",
  flowDropOff: "onboarding_flow_drop_off",
  comprehensionShown: "comprehension_prompt_shown",
  comprehensionIgnored: "comprehension_prompt_ignored",
  recorderAbandoned: "recorder_abandoned",
  rapidNavigation: "rapid_navigation",
} as const;

export type OnboardingClarityEventName =
  (typeof ONBOARDING_CLARITY_EVENTS)[keyof typeof ONBOARDING_CLARITY_EVENTS];

export function trackOnboardingClarityEvent(
  name: OnboardingClarityEventName,
  meta?: Record<string, string>,
): void {
  trackLocalEvent(name, meta);
}

export function trackFirstAhaMoment(entryId: string, noteId: string): void {
  if (hasLocalEvent(ONBOARDING_CLARITY_EVENTS.firstAhaMoment)) return;
  trackOnboardingClarityEvent(ONBOARDING_CLARITY_EVENTS.firstAhaMoment, { entryId, noteId });
  trackOnboardingClarityEvent(ONBOARDING_CLARITY_EVENTS.callbackSurprise, { entryId, noteId });
}

export function trackArchiveUnderstood(source: string): void {
  if (hasLocalEvent(ONBOARDING_CLARITY_EVENTS.archiveUnderstood)) return;
  trackOnboardingClarityEvent(ONBOARDING_CLARITY_EVENTS.archiveUnderstood, { source });
}

export function trackConfusionDetected(level: string, detail: string): void {
  trackOnboardingClarityEvent(ONBOARDING_CLARITY_EVENTS.confusionDetected, {
    level,
    detail: detail.slice(0, 120),
  });
}

export function trackFlowStepCompleted(stepId: string): void {
  trackOnboardingClarityEvent(ONBOARDING_CLARITY_EVENTS.flowStepCompleted, { stepId });
}

export function trackFlowDropOff(stepId: string, reason: string): void {
  trackOnboardingClarityEvent(ONBOARDING_CLARITY_EVENTS.flowDropOff, {
    stepId,
    reason: reason.slice(0, 80),
  });
}

export function trackFirstRevisitDelay(hours: number): void {
  if (hasLocalEvent(ONBOARDING_CLARITY_EVENTS.firstRevisitDelay)) return;
  trackOnboardingClarityEvent(ONBOARDING_CLARITY_EVENTS.firstRevisitDelay, {
    hours: String(Math.round(hours)),
  });
}

export function trackOverwhelmedExit(detail: string): void {
  if (hasLocalEvent(ONBOARDING_CLARITY_EVENTS.overwhelmedExit)) return;
  trackOnboardingClarityEvent(ONBOARDING_CLARITY_EVENTS.overwhelmedExit, {
    detail: detail.slice(0, 80),
  });
}

export function countOnboardingClarityEvents(): Record<string, number> {
  const names = Object.values(ONBOARDING_CLARITY_EVENTS);
  return Object.fromEntries(names.map((name) => [name, countLocalEvents(name)]));
}
