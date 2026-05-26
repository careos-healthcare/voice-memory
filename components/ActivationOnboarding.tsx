"use client";

import { useEffect, useState } from "react";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { X } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  ACTIVATION_LEAD,
  ACTIVATION_ONBOARDING_STEPS,
  ACTIVATION_QUIET_EARLY,
  ACTIVATION_WHY_RETURN,
} from "@/lib/activation-guidance";
import { dismissOnboarding, isOnboardingDismissed } from "@/lib/onboarding";
import { NOT_THERAPY_LINE, PRIVATE_BY_DEFAULT_LINE } from "@/lib/trust-copy";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import {
  trackOnboardingClarityEvent,
  ONBOARDING_CLARITY_EVENTS,
} from "@/lib/onboarding/onboarding-observation";
import { completeFirstSessionStep } from "@/lib/onboarding/first-session-flow";
import { observeRecurrenceDensityOnboardingComplete } from "@/lib/retention/recurrence-density";
import { usePrimaryCtaClaim } from "@/components/homepage/HomepagePrimaryCtaProvider";

export function ActivationOnboarding() {
  const hydrated = useClientHydrated();
  const [visible, setVisible] = useState(false);
  const [step, setStep] = useState(0);

  useEffect(() => {
    setVisible(!isOnboardingDismissed());
  }, []);

  const stepIndex = Math.min(step, ACTIVATION_ONBOARDING_STEPS.length - 1);
  const current = ACTIVATION_ONBOARDING_STEPS[stepIndex]!;
  const isLast = stepIndex >= ACTIVATION_ONBOARDING_STEPS.length - 1;
  const canShowOnboardingCta = usePrimaryCtaClaim(
    "onboarding",
    hydrated && visible && isLast,
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
    <div className="rounded-2xl border border-white/10 bg-white/[0.02] px-4 py-5">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 space-y-4">
          <div>
            <p className="text-sm font-normal leading-relaxed text-zinc-300">{ACTIVATION_LEAD}</p>
            <p className="mt-2 text-xs leading-relaxed text-zinc-600">{ACTIVATION_QUIET_EARLY}</p>
            <p className="mt-2 text-xs leading-relaxed text-zinc-600">{PRIVATE_BY_DEFAULT_LINE}</p>
            <p className="mt-2 text-xs leading-relaxed text-zinc-600">{NOT_THERAPY_LINE}</p>
          </div>

          <p className="text-sm leading-relaxed text-zinc-400">{ACTIVATION_WHY_RETURN}</p>

          <div className="space-y-3">
            <div>
              <p className="text-sm text-zinc-400">{current.label}</p>
              <p className="mt-1 text-sm leading-relaxed text-zinc-500/90">{current.body}</p>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2 pt-1">
            {!isLast ? (
              <Button type="button" size="sm" variant="secondary" onClick={() => setStep((s) => s + 1)}>
                Next
              </Button>
            ) : canShowOnboardingCta ? (
              <Button
                type="button"
                size="sm"
                data-primary-cta="onboarding"
                onClick={() => finish(true)}
              >
                Record a reflection
              </Button>
            ) : null}
            <Button
              type="button"
              size="sm"
              variant="ghost"
              className="text-zinc-600"
              onClick={() => finish(isLast)}
            >
              {isLast ? "Skip for now" : "Skip"}
            </Button>
          </div>
        </div>

        <button
          type="button"
          aria-label="Dismiss"
          className="rounded-full p-1 text-zinc-600 hover:bg-white/5 hover:text-zinc-400"
          onClick={() => finish(false)}
        >
          <X className="h-4 w-4" />
        </button>
      </div>
    </div>
  );
}
