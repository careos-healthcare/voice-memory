"use client";

import { useEffect, useState } from "react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { BLIND_SPOT_PAGE } from "@/lib/blind-spots/blind-spot-copy";
import { applyExperimentFeedbackToCommitment } from "@/lib/blind-spots/blind-spot-experiment-commitment";
import {
  getBlindSpotExperimentFeedback,
  saveBlindSpotExperimentFeedback,
} from "@/lib/blind-spots/blind-spot-experiment-feedback";
import type { BlindSpotReviewResult } from "@/types/blind-spot";
import type { BlindSpotExperimentFeedbackRating } from "@/types/blind-spot-experiment";

const RATING_OPTIONS: BlindSpotExperimentFeedbackRating[] = [
  "will_try",
  "not_useful",
  "already_tried",
];

interface BlindSpotExperimentSectionProps {
  review: BlindSpotReviewResult;
}

export function BlindSpotExperimentSection({ review }: BlindSpotExperimentSectionProps) {
  const experiment = review.experiment;
  const [rating, setRating] = useState<BlindSpotExperimentFeedbackRating | undefined>();
  const [saved, setSaved] = useState(false);
  const [commitmentNote, setCommitmentNote] = useState<string | null>(null);

  useEffect(() => {
    if (!experiment) return;
    setRating(getBlindSpotExperimentFeedback(review.reviewId));
    setSaved(false);
    setCommitmentNote(null);
  }, [review.reviewId, experiment]);

  if (!experiment) return null;

  const labels = BLIND_SPOT_PAGE.experimentReactionLabels;

  function handleSelect(next: BlindSpotExperimentFeedbackRating) {
    if (!experiment) return;
    setRating(next);
    saveBlindSpotExperimentFeedback({
      reviewId: review.reviewId,
      experimentIngredient: experiment.ingredient,
      rating: next,
    });
    applyExperimentFeedbackToCommitment(review, next);
    setCommitmentNote(
      next === "will_try" || next === "already_tried"
        ? BLIND_SPOT_PAGE.experimentCommitmentSaved
        : null,
    );
    setSaved(true);
  }

  return (
    <section className="space-y-4 border-t border-white/5 pt-8">
      <div>
        <h3 className="text-sm font-medium text-zinc-300">{BLIND_SPOT_PAGE.experimentTitle}</h3>
        <p className="mt-1 text-xs leading-relaxed text-zinc-500">
          {BLIND_SPOT_PAGE.experimentDisclaimer}
        </p>
      </div>

      <Card className="border-white/5 bg-black/15">
        <CardContent className="space-y-4 pt-6">
          <div>
            <p className="text-xs uppercase tracking-wider text-zinc-500">
              {BLIND_SPOT_PAGE.experimentSmallThing}
            </p>
            <p className="mt-2 text-sm leading-relaxed text-zinc-300">{experiment.smallThing}</p>
          </div>
          <div>
            <p className="text-xs uppercase tracking-wider text-zinc-500">
              {BLIND_SPOT_PAGE.experimentTryNextTime}
            </p>
            <p className="mt-2 text-sm leading-relaxed text-zinc-400">{experiment.tryNextTime}</p>
          </div>
          <div>
            <p className="text-xs uppercase tracking-wider text-zinc-500">
              {BLIND_SPOT_PAGE.experimentCheckWhether}
            </p>
            <p className="mt-2 text-sm leading-relaxed text-zinc-400">{experiment.checkWhether}</p>
          </div>
        </CardContent>
      </Card>

      <Card className="border-white/5">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-medium text-zinc-300">
            {BLIND_SPOT_PAGE.experimentFeedbackPrompt}
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="flex flex-wrap gap-2">
            {RATING_OPTIONS.map((option) => (
              <Button
                key={option}
                type="button"
                size="sm"
                variant={rating === option ? "default" : "ghost"}
                className={
                  rating === option
                    ? "border-violet-500/40 bg-violet-500/20 text-violet-100"
                    : "border-white/10 text-zinc-400"
                }
                onClick={() => handleSelect(option)}
              >
                {labels[option]}
              </Button>
            ))}
          </div>
          {saved ? (
            <p className="text-xs text-zinc-600">
              {commitmentNote ?? "Saved locally — only on this device."}
            </p>
          ) : null}
        </CardContent>
      </Card>
    </section>
  );
}
