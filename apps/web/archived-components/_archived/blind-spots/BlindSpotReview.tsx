"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { InsightScorecardPanel } from "@/archived-components/_archived/insights/InsightScorecardPanel";
import { BlindSpotBreakthroughPrompt } from "@/archived-components/_archived/breakthrough/BreakthroughTrackingPrompt";
import { BreakthroughCapturePrompt } from "@/archived-components/_archived/blind-spots/BreakthroughCapturePrompt";
import { recordBreakthroughEligibleSurface } from "@/lib/breakthrough/breakthrough-prompt-gate";
import { BlindSpotExperimentSection } from "@/archived-components/_archived/blind-spots/BlindSpotExperimentSection";
import { BlindSpotExperimentFollowUpStack } from "@/archived-components/_archived/blind-spots/BlindSpotExperimentFollowUpStack";
import { InsightOutcomePromptStack } from "@/archived-components/_archived/insights/InsightOutcomePromptStack";
import { BlindSpotReviewChangesSection } from "@/archived-components/_archived/blind-spots/BlindSpotReviewChangesSection";
import { DelayedValidationPrompt } from "@/archived-components/_archived/blind-spots/DelayedValidationPrompt";
import {
  getBlindSpotReaction,
  saveBlindSpotReaction,
} from "@/lib/blind-spots/blind-spot-feedback";
import {
  BLIND_SPOT_EVENTS,
  trackBlindSpotEvent,
} from "@/lib/blind-spots/blind-spot-events";
import { EvidenceQualityBadge } from "@/archived-components/_archived/blind-spots/EvidenceQualityBadge";
import { TheoryConfidenceMovement } from "@/archived-components/_archived/theories/TheoryConfidenceMovement";
import { EVIDENCE_QUALITY_COPY } from "@/lib/blind-spots/a-tier-prioritization";
import { ValueMomentPaywall } from "@/archived-components/_archived/billing/ValueMomentPaywall";
import { markFirstBlindSpotSeen } from "@/lib/billing/value-moment-paywall";
import { WhatHappensNextPanel } from "@/archived-components/_archived/blind-spots/WhatHappensNextPanel";
import { recordFirstWorkingTheorySeen } from "@/lib/metrics/evolving-understanding-events";
import { observeFirstValueMoment } from "@/lib/retention/first-value-moments";
import { getDueDelayedValidations } from "@/lib/blind-spots/delayed-validation";
import {
  BLIND_SPOT_FIRST_REVIEW,
  BLIND_SPOT_PAGE,
  EVIDENCE_STRENGTH_LABELS,
} from "@/lib/blind-spots/blind-spot-copy";
import type { BlindSpotReaction, BlindSpotReviewReport } from "@/types/blind-spot";
import { BLIND_SPOT_EVIDENCE_FIRST_SECTIONS } from "@/types/blind-spot-acceleration";
import type { DelayedValidationRecord } from "@/types/blind-spot-discovery";
import type { JournalEntry } from "@/types/journal";

const REACTION_OPTIONS: BlindSpotReaction[] = [
  "obvious",
  "interesting",
  "surprising",
  "uncomfortably_accurate",
  "completely_wrong",
];

function strengthBarClass(label: string): string {
  switch (label) {
    case "very_high":
      return "bg-violet-400/80";
    case "high":
      return "bg-violet-400/60";
    case "medium":
      return "bg-violet-400/40";
    default:
      return "bg-violet-400/25";
  }
}

interface BlindSpotReviewProps {
  mainReview: BlindSpotReviewReport;
  showEmergingHint?: boolean;
  reflectionCount: number;
  archiveAgeDays: number;
  entries: JournalEntry[];
}

export function BlindSpotReview({
  mainReview,
  showEmergingHint = false,
  reflectionCount,
  archiveAgeDays,
  entries,
}: BlindSpotReviewProps) {
  const [reaction, setReaction] = useState<BlindSpotReaction | undefined>();
  const [comment, setComment] = useState("");
  const [showComment, setShowComment] = useState(false);
  const [saved, setSaved] = useState(false);
  const [lastFeedbackId, setLastFeedbackId] = useState<string | null>(null);
  const [dueDelayed, setDueDelayed] = useState<DelayedValidationRecord[]>([]);
  const openTrackRef = useRef(false);

  const refreshDelayed = () => setDueDelayed(getDueDelayedValidations());

  useEffect(() => {
    refreshDelayed();
  }, []);

  useEffect(() => {
    if (mainReview.kind === "ready") {
      setReaction(getBlindSpotReaction(mainReview.review.reviewId));
      if (!openTrackRef.current) {
        openTrackRef.current = true;
        const { review } = mainReview;
        trackBlindSpotEvent(BLIND_SPOT_EVENTS.blindSpotOpened, {
          reviewId: review.reviewId,
          evidenceStrength: review.evidenceStrength,
          estimatedImpactScore: review.estimatedImpactScore,
          reflectionCount,
          archiveAgeDays,
          patternType: review.reviewId.split(":")[1],
        });
        observeFirstValueMoment("blind_spot_viewed");
        markFirstBlindSpotSeen();
        recordFirstWorkingTheorySeen();
      }
    }
  }, [mainReview, reflectionCount, archiveAgeDays]);

  if (mainReview.kind === "empty") {
    return (
      <Card className="border-dashed border-white/5">
        <CardContent className="py-14 text-center">
          <p className="text-sm leading-relaxed text-zinc-400">{mainReview.message}</p>
          {mainReview.reason === "insufficient_reflections" ? (
            <p className="mt-3 text-xs text-zinc-600">
              {mainReview.reflectionCount} of 5 reflections for a full blind spot review.
              {showEmergingHint ? " Emerging patterns above may still apply." : ""}
            </p>
          ) : (
            <p className="mt-3 text-xs text-zinc-600">
              Keep recording — cross-entry repetition over time raises evidence strength.
              {showEmergingHint ? " Watch emerging patterns above as hypotheses build." : ""}
            </p>
          )}
        </CardContent>
      </Card>
    );
  }

  const { review, sinceLastTime } = mainReview;
  const facts = review.evidenceStrengthFacts;
  const strengthLabel = EVIDENCE_STRENGTH_LABELS[review.evidenceStrength];
  const sectionOrder = BLIND_SPOT_EVIDENCE_FIRST_SECTIONS;

  const submitReaction = (next: BlindSpotReaction) => {
    const record = saveBlindSpotReaction({
      reviewId: review.reviewId,
      reaction: next,
      comment: showComment ? comment : undefined,
      headline: review.headline,
      evidenceStrength: review.evidenceStrength,
      estimatedImpactScore: review.estimatedImpactScore,
      reflectionCount,
      archiveAgeDays,
      entries,
    });
    setReaction(next);
    setLastFeedbackId(record.id);
    setSaved(true);
    recordBreakthroughEligibleSurface();
    refreshDelayed();
  };

  const showBreakthrough =
    saved &&
    lastFeedbackId &&
    (reaction === "surprising" || reaction === "uncomfortably_accurate");

  const evidenceSection = (
    <section key="evidence" className="space-y-4" data-section={sectionOrder[0]}>
      <h3 className="text-sm font-medium text-zinc-300">{BLIND_SPOT_PAGE.evidenceLead}</h3>
      <ul className="space-y-4">
        {review.evidenceQuotes.map((item) => (
          <li
            key={`${item.entryId}-${item.dateLabel}`}
            className="rounded-xl border border-white/5 bg-black/20 p-4"
          >
            <p className="text-[11px] uppercase tracking-wider text-zinc-500">{item.dateLabel}</p>
            <blockquote className="mt-2 border-l-2 border-violet-400/30 pl-3 text-sm leading-relaxed text-zinc-200">
              “{item.quote}”
            </blockquote>
            <Link
              href={`/entry/${item.entryId}`}
              className="mt-3 inline-block text-xs text-zinc-500 underline-offset-2 hover:text-violet-300 hover:underline"
            >
              Open reflection
            </Link>
          </li>
        ))}
      </ul>
    </section>
  );

  const observationSection = (
    <section key="observation" className="space-y-2" data-section={sectionOrder[1]}>
      <h3 className="text-sm font-medium text-zinc-300">{BLIND_SPOT_PAGE.observationTitle}</h3>
      <p className="text-sm leading-relaxed text-zinc-400">{review.observation}</p>
    </section>
  );

  const firstTheoryFraming = (
    <section
      key="firstWorkingTheoryFraming"
      className="space-y-2 rounded-xl border border-violet-500/10 bg-violet-950/10 px-4 py-3"
      data-section="firstWorkingTheoryFraming"
    >
      <p className="text-sm leading-relaxed text-violet-100/80">
        {BLIND_SPOT_FIRST_REVIEW.notVerdict}
      </p>
      <p className="text-sm leading-relaxed text-zinc-500">{BLIND_SPOT_FIRST_REVIEW.mayChange}</p>
      <p className="text-sm leading-relaxed text-zinc-500">{BLIND_SPOT_FIRST_REVIEW.archiveView}</p>
    </section>
  );

  const patternSection = (
    <section key="possiblePattern" className="space-y-3" data-section={sectionOrder[2]}>
      <p className="text-xs uppercase tracking-[0.18em] text-violet-300/80">
        {BLIND_SPOT_PAGE.mostExpensiveBelief}
      </p>
      <div className="flex flex-wrap items-start justify-between gap-3">
        <h2 className="text-xl font-semibold leading-snug text-zinc-100">{review.headline}</h2>
        <EvidenceQualityBadge profile={review.ingredientProfile} />
      </div>
      {review.currentConfidence !== undefined ? (
        <TheoryConfidenceMovement
          input={{
            currentConfidence: review.currentConfidence,
            previousConfidence: review.previousConfidence,
            delta: review.confidenceDelta,
            lifeAreaHint:
              review.linkedAreas[0] !== "General" ? review.linkedAreas[0] : undefined,
            contradictingCount: review.evidenceStrengthFacts.contradictionPresent ? 1 : 0,
            supportingCount: review.evidenceStrengthFacts.reflectionCount,
          }}
          className="mt-3"
        />
      ) : null}
      {review.contradictionNote ? (
        <p className="text-sm leading-relaxed text-zinc-500">{review.contradictionNote}</p>
      ) : null}
      {review.predictionEvidenceNote ? (
        <p className="text-sm leading-relaxed text-zinc-500">{review.predictionEvidenceNote}</p>
      ) : null}
      <div>
        <h3 className="text-sm font-medium text-zinc-300">{BLIND_SPOT_PAGE.possiblePatternTitle}</h3>
        <p className="mt-2 text-sm leading-relaxed text-zinc-300">{review.possibleBelief}</p>
        <p className="mt-2 text-sm leading-relaxed text-zinc-500">{review.pattern}</p>
        {review.rootBeliefHypothesis ? (
          <p className="mt-3 text-sm leading-relaxed text-zinc-400">{review.rootBeliefHypothesis}</p>
        ) : null}
      </div>
      <p className="text-xs leading-relaxed text-zinc-600">{review.disclaimer}</p>
    </section>
  );

  const whySection = (
    <section key="whyItMayMatter" className="space-y-4" data-section={sectionOrder[3]}>
      <h3 className="text-sm font-medium text-zinc-300">{BLIND_SPOT_PAGE.whyMayMatterTitle}</h3>
      {review.whyMatterBullets && review.whyMatterBullets.length > 0 ? (
        <div className="rounded-xl border border-emerald-500/15 bg-emerald-950/10 px-4 py-3">
          <p className="text-xs leading-relaxed text-emerald-200/80">
            {EVIDENCE_QUALITY_COPY.whyMayMatterLead}
          </p>
          <ul className="mt-2 list-inside list-disc space-y-1.5 text-sm text-zinc-300">
            {review.whyMatterBullets.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        </div>
      ) : null}
      <div className="space-y-3 rounded-xl border border-white/5 bg-black/10 p-4">
        <div>
          <p className="text-xs uppercase tracking-wider text-zinc-500">
            {BLIND_SPOT_PAGE.likelyCostTitle}
          </p>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">{review.likelyCost}</p>
        </div>
        {review.possibleCostLead ? (
          <p className="text-sm leading-relaxed text-zinc-500">{review.possibleCostLead}</p>
        ) : null}
        {review.costEvidenceLines.length > 0 ? (
          <div className="border-t border-white/5 pt-3">
            <p className="text-xs uppercase tracking-wider text-zinc-500">
              {BLIND_SPOT_PAGE.costEvidenceTitle}
            </p>
            <p className="mt-1 text-xs text-zinc-600">{BLIND_SPOT_PAGE.costEvidenceLead}</p>
            <ul className="mt-2 space-y-1.5">
              {review.costEvidenceLines.map((line) => (
                <li key={line} className="text-sm text-zinc-400">
                  {line}
                </li>
              ))}
            </ul>
          </div>
        ) : null}
        <div className="border-t border-white/5 pt-3">
          <p className="text-xs uppercase tracking-wider text-zinc-500">
            {BLIND_SPOT_PAGE.ifSoftenedTitle}
          </p>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">{review.ifThisDisappeared}</p>
        </div>
      </div>
    </section>
  );

  return (
    <div className="space-y-8 border-t border-white/5 pt-10">
      {dueDelayed.length > 0 ? (
        <div className="space-y-3">
          {dueDelayed.map((record) => (
            <DelayedValidationPrompt
              key={record.id}
              record={record}
              onAnswered={refreshDelayed}
            />
          ))}
        </div>
      ) : null}

      <BlindSpotReviewChangesSection changes={sinceLastTime} />

      <BlindSpotExperimentFollowUpStack className="mb-2" />
      <InsightOutcomePromptStack className="mb-2" />

      <Card className="border-white/5 bg-black/20">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-medium text-zinc-300">
            {BLIND_SPOT_PAGE.evidenceStrengthTitle}
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center gap-3">
            <span className="text-lg font-semibold text-violet-200">{strengthLabel}</span>
            <div className="h-2 flex-1 overflow-hidden rounded-full bg-white/5">
              <div
                className={`h-full rounded-full transition-all ${strengthBarClass(review.evidenceStrength)}`}
                style={{
                  width:
                    review.evidenceStrength === "very_high"
                      ? "100%"
                      : review.evidenceStrength === "high"
                        ? "78%"
                        : review.evidenceStrength === "medium"
                          ? "55%"
                          : "30%",
                }}
              />
            </div>
          </div>
          <ul className="space-y-1.5 text-sm text-zinc-400">
            <li>
              <span className="text-zinc-500">Reflections:</span> {facts.reflectionCount} matching
            </li>
            <li>
              <span className="text-zinc-500">Time span:</span> {facts.richSpanLabel} ({facts.spanLabel})
            </li>
            <li>
              <span className="text-zinc-500">Life areas:</span> {facts.lifeAreaCount}
              {facts.lifeAreas.length > 0 ? ` — e.g. ${facts.lifeAreas.join(", ")}` : null}
            </li>
            {facts.lifeAreaSpreadLabel ? (
              <li className="text-zinc-500">{facts.lifeAreaSpreadLabel}</li>
            ) : null}
            {facts.contradictionPresent ? (
              <li className="text-zinc-500">Contradiction signal in archive</li>
            ) : null}
            {facts.failedPredictionCount > 0 ? (
              <li className="text-zinc-500">Later evidence may not match an earlier prediction</li>
            ) : null}
          </ul>
        </CardContent>
      </Card>

      {firstTheoryFraming}
      {patternSection}
      <WhatHappensNextPanel className="mt-2" />
      {whySection}
      <BlindSpotExperimentSection review={review} />

      {evidenceSection}
      {observationSection}

      <section className="space-y-2 border-t border-white/5 pt-8">
        <h3 className="text-sm font-medium text-zinc-300">{BLIND_SPOT_PAGE.alternativeTitle}</h3>
        <p className="text-sm leading-relaxed text-zinc-400">{review.alternativeToTest}</p>
      </section>

      {review.scorecard ? <InsightScorecardPanel scorecard={review.scorecard} /> : null}

      <Card className="border-white/5">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-medium text-zinc-300">
            {BLIND_SPOT_PAGE.feedbackPrompt}
          </CardTitle>
          <p className="text-xs leading-relaxed text-zinc-500">{BLIND_SPOT_PAGE.feedbackHelper}</p>
        </CardHeader>
        <CardContent className="space-y-4">
          <div
            className="flex flex-col gap-2"
            role="radiogroup"
            aria-label="How did this blind spot land?"
          >
            {REACTION_OPTIONS.map((option) => (
              <label
                key={option}
                className={`flex cursor-pointer items-center gap-3 rounded-xl border px-4 py-3 text-sm transition ${
                  reaction === option
                    ? "border-violet-400/40 bg-violet-500/10 text-zinc-100"
                    : "border-white/10 bg-black/10 text-zinc-400 hover:border-white/20"
                }`}
              >
                <input
                  type="radio"
                  name="blind-spot-reaction"
                  value={option}
                  checked={reaction === option}
                  onChange={() => submitReaction(option)}
                  className="h-4 w-4 border-white/20 bg-transparent text-violet-500 focus:ring-violet-400/40"
                />
                <span>{BLIND_SPOT_PAGE.reactionLabels[option]}</span>
              </label>
            ))}
          </div>

          {!showComment ? (
            <Button
              type="button"
              size="sm"
              variant="ghost"
              className="text-zinc-500"
              onClick={() => setShowComment(true)}
            >
              Add optional note
            </Button>
          ) : (
            <div className="space-y-2">
              <textarea
                value={comment}
                onChange={(event) => setComment(event.target.value)}
                placeholder="Optional — what felt new, off, or already known?"
                rows={2}
                className="w-full rounded-xl border border-white/10 bg-black/20 px-3 py-2 text-sm text-zinc-200 placeholder:text-zinc-600 focus:border-violet-400/40 focus:outline-none"
              />
              {reaction ? (
                <Button
                  type="button"
                  size="sm"
                  variant="ghost"
                  onClick={() => submitReaction(reaction)}
                >
                  Update note
                </Button>
              ) : null}
            </div>
          )}

          {saved ? (
            <p className="text-xs text-zinc-600">
              Saved locally — helps measure genuine self-recognition, not agreement.
            </p>
          ) : null}

          {showBreakthrough && lastFeedbackId && reaction ? (
            <>
              <BlindSpotBreakthroughPrompt review={review} reaction={reaction} />
              <BreakthroughCapturePrompt
                feedbackId={lastFeedbackId}
                reviewId={review.reviewId}
                reaction={reaction}
              />
            </>
          ) : null}
        </CardContent>
      </Card>

      <ValueMomentPaywall surface="blind_spot" entriesOverride={entries} className="mt-6" />
    </div>
  );
}
