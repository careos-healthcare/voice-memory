"use client";

import { useEffect, useState } from "react";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";

import { isOnboardingDismissed } from "@/lib/onboarding";
import { EmotionalProofLine } from "@/components/social-proof/EmotionalProofLine";

export function OnboardingCompletionProof() {
  const hydrated = useClientHydrated();
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    setVisible(isOnboardingDismissed());
  }, []);

  if (!hydrated || !visible) return null;

  return (
    <div className="pt-2">
      <EmotionalProofLine surface="onboarding_complete" />
    </div>
  );
}
