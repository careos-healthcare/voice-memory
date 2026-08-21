"use client";

import { useEffect, useState } from "react";

import { Button } from "@/archived-components/_archived/ui/button";
import { buildBlindSpotAttribution, buildTheoryAttribution } from "@/lib/breakthrough/breakthrough-attribution";
import {
  pickBlindSpotBreakthroughPrompt,
  pickTheoryBreakthroughPrompt,
  resolveBreakthroughType,
} from "@/lib/breakthrough/breakthrough-copy";
import { saveBreakthroughEvent } from "@/lib/breakthrough/breakthrough-events";
import {
  offerInsightOutcomeAfterBlindSpotReview,
  offerInsightOutcomeAfterTheory,
} from "@/lib/insights/insight-outcome-schedule";
import {
  readShownBreakthroughPromptIds,
  recordBreakthroughPromptDismissed,
  recordBreakthroughPromptShown,
  shouldOfferBreakthroughPrompt,
} from "@/lib/breakthrough/breakthrough-prompt-gate";
import type { BreakthroughPromptAnswer, BreakthroughPromptOffer } from "@/types/breakthrough-tracking";
import type { BlindSpotReviewResult } from "@/types/blind-spot";
import type { Theory } from "@/types/theory";

interface BlindSpotBreakthroughPromptProps {
  review: BlindSpotReviewResult;
  reaction: "surprising" | "uncomfortably_accurate";
}

interface TheoryBreakthroughPromptProps {
  theory: Theory;
}

function useBreakthroughOffer(
  factory: () => BreakthroughPromptOffer | null,
  deps: unknown[],
): BreakthroughPromptOffer | null {
  const [offer, setOffer] = useState<BreakthroughPromptOffer | null>(null);

  useEffect(() => {
    if (!shouldOfferBreakthroughPrompt()) {
      setOffer(null);
      return;
    }
    const next = factory();
    if (next) {
      recordBreakthroughPromptShown(next.id);
      setOffer(next);
    }
  }, deps);

  return offer;
}

function BreakthroughPromptBody({
  offer,
  onAnswer,
  onDismiss,
}: {
  offer: BreakthroughPromptOffer;
  onAnswer: (answer: BreakthroughPromptAnswer) => void;
  onDismiss: () => void;
}) {
  return (
    <div className="rounded-xl border border-white/[0.06] bg-zinc-900/40 px-4 py-4">
      <p className="text-sm leading-relaxed text-zinc-300">{offer.question}</p>
      <div className="mt-3 flex flex-wrap gap-2">
        <Button type="button" size="sm" variant="secondary" onClick={() => onAnswer("yes")}>
          Yes
        </Button>
        <Button type="button" size="sm" variant="ghost" onClick={() => onAnswer("not_sure")}>
          Not sure
        </Button>
        <Button type="button" size="sm" variant="ghost" onClick={() => onAnswer("no")}>
          No
        </Button>
      </div>
      <button
        type="button"
        onClick={onDismiss}
        className="mt-3 text-xs text-zinc-600 hover:text-zinc-400"
      >
        Skip
      </button>
    </div>
  );
}

export function BlindSpotBreakthroughPrompt({
  review,
  reaction,
}: BlindSpotBreakthroughPromptProps) {
  const [done, setDone] = useState(false);
  const offer = useBreakthroughOffer(
    () => pickBlindSpotBreakthroughPrompt(reaction, readShownBreakthroughPromptIds()),
    [review.reviewId, reaction],
  );

  if (done || !offer) return null;

  const submit = (answer: BreakthroughPromptAnswer) => {
    const type =
      answer === "yes" && reaction === "uncomfortably_accurate" && offer.id === "insight_changed"
        ? "blind_spot_resolved"
        : resolveBreakthroughType(offer.id, answer);

    saveBreakthroughEvent({
      type,
      answer,
      promptId: offer.id,
      relatedBlindSpotId: review.reviewId,
      attribution: buildBlindSpotAttribution(review),
    });
    offerInsightOutcomeAfterBlindSpotReview(review, "breakthrough_followup");
    setDone(true);
  };

  const dismiss = () => {
    recordBreakthroughPromptDismissed();
    setDone(true);
  };

  return (
    <BreakthroughPromptBody offer={offer} onAnswer={submit} onDismiss={dismiss} />
  );
}

export function TheoryBreakthroughPrompt({ theory }: TheoryBreakthroughPromptProps) {
  const [done, setDone] = useState(false);
  const offer = useBreakthroughOffer(
    () => pickTheoryBreakthroughPrompt(readShownBreakthroughPromptIds()),
    [theory.id],
  );

  if (done || !offer) return null;

  const submit = (answer: BreakthroughPromptAnswer) => {
    saveBreakthroughEvent({
      type: resolveBreakthroughType(offer.id, answer),
      answer,
      promptId: offer.id,
      relatedTheoryId: theory.id,
      attribution: buildTheoryAttribution(theory),
    });
    offerInsightOutcomeAfterTheory(theory);
    setDone(true);
  };

  const dismiss = () => {
    recordBreakthroughPromptDismissed();
    setDone(true);
  };

  return (
    <BreakthroughPromptBody offer={offer} onAnswer={submit} onDismiss={dismiss} />
  );
}
