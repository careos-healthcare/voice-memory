"use client";

import { useState } from "react";

import { Button } from "@/archived-components/_archived/ui/button";
import {
  ONBOARDING_CONFIDENCE_PROMPT,
  buildOnboardingConfidenceResult,
  persistOnboardingConfidenceResult,
  type OnboardingProductPerceptionCategory,
} from "@/lib/onboarding/onboarding-confidence-check";

const CATEGORY_HINT: Record<OnboardingProductPerceptionCategory, string> = {
  tracks_archive_belief: "Archive belief — strong signal",
  journal: "Journal framing — refine onboarding",
  ai_coach: "AI coach framing — refine onboarding",
  notes_app: "Notes app framing — refine onboarding",
  therapy_app: "Therapy app framing — refine onboarding",
  unclear: "Unclear — ask a follow-up",
};

type OnboardingConfidenceCheckProps = {
  onComplete: () => void;
};

export function OnboardingConfidenceCheck({ onComplete }: OnboardingConfidenceCheckProps) {
  const [answer, setAnswer] = useState("");
  const [submitted, setSubmitted] = useState(false);
  const [category, setCategory] = useState<OnboardingProductPerceptionCategory | null>(
    null,
  );

  const handleSubmit = () => {
    const trimmed = answer.trim();
    if (!trimmed) return;
    const result = buildOnboardingConfidenceResult(trimmed);
    persistOnboardingConfidenceResult(result);
    setCategory(result.category);
    setSubmitted(true);
  };

  return (
    <div
      className="mt-4 space-y-3 rounded-xl border border-white/10 bg-black/25 px-4 py-4"
      data-testid="onboarding-confidence-check"
    >
      <p className="text-sm font-medium text-zinc-200">{ONBOARDING_CONFIDENCE_PROMPT}</p>
      {!submitted ? (
        <>
          <textarea
            value={answer}
            onChange={(e) => setAnswer(e.target.value)}
            rows={2}
            className="w-full rounded-lg border border-white/10 bg-zinc-950 px-3 py-2 text-sm text-zinc-200 outline-none ring-violet-500/30 focus:ring-2"
            placeholder="One sentence is enough."
            aria-label={ONBOARDING_CONFIDENCE_PROMPT}
          />
          <Button type="button" size="sm" disabled={!answer.trim()} onClick={handleSubmit}>
            Save answer
          </Button>
        </>
      ) : (
        <p className="text-xs text-zinc-500">
          {category ? CATEGORY_HINT[category] : null}
        </p>
      )}
      {submitted ? (
        <Button type="button" size="sm" variant="secondary" onClick={onComplete}>
          Continue
        </Button>
      ) : null}
    </div>
  );
}
