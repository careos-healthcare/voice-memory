"use client";

import { useEffect, useState } from "react";
import { X } from "lucide-react";

import { OnboardingConfidenceCheck } from "@/archived-components/_archived/onboarding/OnboardingConfidenceCheck";
import { Button } from "@/archived-components/_archived/ui/button";
import { dismissOnboarding, isOnboardingDismissed } from "@/lib/onboarding";
import {
  ARCHIVE_ONBOARDING_RECORD_CTA,
  ARCHIVE_ONBOARDING_SCREENS,
} from "@/lib/onboarding/archive-onboarding-copy";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import {
  ONBOARDING_CLARITY_EVENTS,
  trackOnboardingClarityEvent,
} from "@/lib/onboarding/onboarding-observation";
import { completeFirstSessionStep } from "@/lib/onboarding/first-session-flow";
import { observeRecurrenceDensityOnboardingComplete } from "@/lib/retention/recurrence-density";
import { usePrimaryCtaClaim } from "@/archived-components/_archived/homepage/HomepagePrimaryCtaProvider";

/**
 * Archive onboarding — headlines only; confidence check on completion.
 */
export function ArchiveOnboarding() {
  const hydrated = useClientHydrated();
  const [visible, setVisible] = useState(false);
  const [step, setStep] = useState(0);
  const [confidenceDone, setConfidenceDone] = useState(false);

  useEffect(() => {
    setVisible(!isOnboardingDismissed());
  }, []);

  const stepIndex = Math.min(step, ARCHIVE_ONBOARDING_SCREENS.length - 1);
  const screen = ARCHIVE_ONBOARDING_SCREENS[stepIndex]!;
  const isLast = stepIndex >= ARCHIVE_ONBOARDING_SCREENS.length - 1;
  const canShowRecordCta = usePrimaryCtaClaim(
    "onboarding",
    hydrated && visible && isLast && confidenceDone,
  );

  if (!hydrated || !visible) return null;

  const finish = (scrollToRecorder: boolean) => {
    dismissOnboarding();
    trackLaunchEvent(LAUNCH_EVENTS.onboardingCompleted);
    trackOnboardingClarityEvent(ONBOARDING_CLARITY_EVENTS.onboardingCompleted);
    observeRecurrenceDensityOnboardingComplete();
    completeFirstSessionStep("archive_perception");
    setVisible(false);
    if (scrollToRecorder) {
      requestAnimationFrame(() => {
        document.getElementById("recorder")?.scrollIntoView({ behavior: "smooth", block: "center" });
      });
    }
  };

  return (
    <div
      className="rounded-2xl border border-violet-500/25 bg-violet-950/20 px-5 py-6"
      data-testid="archive-onboarding"
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1 space-y-5">
          <div className="flex gap-1.5" aria-hidden>
            {ARCHIVE_ONBOARDING_SCREENS.map((s, i) => (
              <span
                key={s.id}
                className={`h-1.5 flex-1 rounded-full transition-colors ${
                  i <= stepIndex ? "bg-violet-400/90" : "bg-white/10"
                }`}
              />
            ))}
          </div>

          <p className="text-xl font-medium leading-snug tracking-tight text-zinc-50 sm:text-2xl">
            {screen.headline}
          </p>

          {isLast ? (
            <OnboardingConfidenceCheck onComplete={() => setConfidenceDone(true)} />
          ) : null}

          <div className="flex flex-wrap items-center gap-2 pt-1">
            {!isLast ? (
              <Button type="button" size="sm" variant="secondary" onClick={() => setStep((s) => s + 1)}>
                Next
              </Button>
            ) : canShowRecordCta ? (
              <Button
                type="button"
                size="sm"
                data-primary-cta="onboarding"
                data-testid="archive-onboarding-record-cta"
                onClick={() => finish(true)}
              >
                {ARCHIVE_ONBOARDING_RECORD_CTA}
              </Button>
            ) : null}
            <Button
              type="button"
              size="sm"
              variant="ghost"
              className="text-zinc-600"
              onClick={() => finish(isLast && confidenceDone)}
              disabled={isLast && !confidenceDone}
            >
              {isLast ? (confidenceDone ? "Skip for now" : "Answer above to continue") : "Skip"}
            </Button>
          </div>
        </div>

        <button
          type="button"
          aria-label="Dismiss onboarding"
          className="rounded-full p-1 text-zinc-600 hover:bg-white/5 hover:text-zinc-400"
          onClick={() => (isLast && !confidenceDone ? undefined : finish(false))}
          disabled={isLast && !confidenceDone}
        >
          <X className="h-4 w-4" />
        </button>
      </div>
    </div>
  );
}
