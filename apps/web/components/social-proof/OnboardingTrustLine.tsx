"use client";

import { useEffect, useState } from "react";

import {
  markOnboardingTrustShown,
  resolveOnboardingTrustAfterRevisit,
} from "@/lib/social-proof/onboarding-trust";

export function OnboardingTrustLine({
  isRevisit,
  hasRevisitReward,
  hasThenVsNow,
  reopenPayoffScore,
  audioReplayed,
}: {
  isRevisit: boolean;
  hasRevisitReward: boolean;
  hasThenVsNow: boolean;
  reopenPayoffScore: number | null;
  audioReplayed?: boolean;
}) {
  const [line, setLine] = useState<string | null>(null);

  useEffect(() => {
    const resolved = resolveOnboardingTrustAfterRevisit({
      isRevisit,
      hasRevisitReward,
      hasThenVsNow,
      reopenPayoffScore,
      audioReplayed,
    });
    if (resolved.showLine && resolved.text) {
      setLine(resolved.text);
      markOnboardingTrustShown();
    }
  }, [isRevisit, hasRevisitReward, hasThenVsNow, reopenPayoffScore, audioReplayed]);

  if (!line) return null;

  return (
    <p className="mt-6 text-sm leading-relaxed text-zinc-500/90">{line}</p>
  );
}
