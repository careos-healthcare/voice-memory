"use client";

import { useEffect, useState } from "react";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { X } from "lucide-react";

import { Button } from "@/components/ui/button";
import { dismissOnboarding, isOnboardingDismissed } from "@/lib/onboarding";
import { ARCHIVE_ONBOARDING_SCREENS } from "@/lib/onboarding/archive-onboarding-copy";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";

export function OnboardingBanner() {
  const hydrated = useClientHydrated();
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    setVisible(!isOnboardingDismissed());
  }, []);

  if (!hydrated || !visible) return null;

  const complete = () => {
    dismissOnboarding();
    trackLaunchEvent(LAUNCH_EVENTS.onboardingCompleted);
    setVisible(false);
  };

  return (
    <div className="rounded-2xl border border-violet-400/25 bg-violet-500/10 px-4 py-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-sm font-medium leading-relaxed text-violet-100">
            {ARCHIVE_ONBOARDING_SCREENS[0]!.headline}
          </p>
          <Button type="button" size="sm" className="mt-3" onClick={complete}>
            Got it
          </Button>
        </div>
        <button
          type="button"
          aria-label="Dismiss"
          className="rounded-full p-1 text-zinc-500 hover:bg-white/5 hover:text-zinc-300"
          onClick={complete}
        >
          <X className="h-4 w-4" />
        </button>
      </div>
    </div>
  );
}
