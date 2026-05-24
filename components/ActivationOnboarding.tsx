"use client";

import { useState } from "react";
import { X } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  ACTIVATION_CONVERSATION,
  ACTIVATION_LEAD,
  ACTIVATION_ONBOARDING_STEPS,
  ACTIVATION_QUIET_EARLY,
} from "@/lib/activation-guidance";
import { dismissOnboarding, isOnboardingDismissed } from "@/lib/onboarding";
import { PRIVATE_BY_DEFAULT_LINE } from "@/lib/trust-copy";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";

export function ActivationOnboarding() {
  const [visible, setVisible] = useState(
    () => typeof window !== "undefined" && !isOnboardingDismissed(),
  );
  const [step, setStep] = useState(0);

  if (!visible) return null;

  const complete = () => {
    dismissOnboarding();
    trackLaunchEvent(LAUNCH_EVENTS.onboardingCompleted);
    setVisible(false);
  };

  const current = ACTIVATION_ONBOARDING_STEPS[step];
  const isLast = step >= ACTIVATION_ONBOARDING_STEPS.length - 1;

  return (
    <div className="rounded-2xl border border-white/10 bg-white/[0.02] px-4 py-5">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 space-y-4">
          <div>
            <p className="text-sm font-normal leading-relaxed text-zinc-300">{ACTIVATION_LEAD}</p>
            <p className="mt-2 text-xs leading-relaxed text-zinc-600">{ACTIVATION_QUIET_EARLY}</p>
            <p className="mt-2 text-xs leading-relaxed text-zinc-600">{PRIVATE_BY_DEFAULT_LINE}</p>
          </div>

          <div className="space-y-3">
            <div>
              <p className="text-sm text-zinc-400">{current.label}</p>
              <p className="mt-1 text-sm leading-relaxed text-zinc-500/90">{current.body}</p>
            </div>
          </div>

          {isLast ? (
            <p className="text-xs leading-relaxed text-zinc-600">{ACTIVATION_CONVERSATION}</p>
          ) : null}

          <div className="flex flex-wrap items-center gap-2 pt-1">
            {!isLast ? (
              <Button type="button" size="sm" variant="secondary" onClick={() => setStep((s) => s + 1)}>
                Next
              </Button>
            ) : (
              <Button type="button" size="sm" onClick={complete}>
                Begin
              </Button>
            )}
            <Button type="button" size="sm" variant="ghost" className="text-zinc-600" onClick={complete}>
              Skip
            </Button>
          </div>
        </div>

        <button
          type="button"
          aria-label="Dismiss"
          className="rounded-full p-1 text-zinc-600 hover:bg-white/5 hover:text-zinc-400"
          onClick={complete}
        >
          <X className="h-4 w-4" />
        </button>
      </div>
    </div>
  );
}
