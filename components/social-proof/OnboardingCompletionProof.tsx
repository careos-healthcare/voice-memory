"use client";

import { useEffect, useState } from "react";

import { isOnboardingDismissed } from "@/lib/onboarding";
import { EmotionalProofLine } from "@/components/social-proof/EmotionalProofLine";

export function OnboardingCompletionProof() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    setVisible(isOnboardingDismissed());
  }, []);

  if (!visible) return null;

  return (
    <div className="pt-2">
      <EmotionalProofLine surface="onboarding_complete" />
    </div>
  );
}
