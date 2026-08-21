"use client";

import { useEffect, useRef, useState } from "react";
import { ChevronDown } from "lucide-react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader } from "@/archived-components/_archived/ui/card";
import {
  getLatestTheoryFeedback,
  saveTheoryFeedback,
} from "@/lib/theories/theory-feedback";
import { trackTheoryEvent, THEORY_EVENTS } from "@/lib/theories/theory-events";
import {
  THEORY_FEEDBACK_LABELS,
  THEORY_PAGE,
} from "@/lib/theories/theory-copy";
import { buildTheoryUncertaintyFromTheory } from "@/lib/theories/theory-uncertainty";
import { InsightScorecardPanel } from "@/archived-components/_archived/insights/InsightScorecardPanel";
import { TheoryBreakthroughPrompt } from "@/archived-components/_archived/breakthrough/BreakthroughTrackingPrompt";
import { offerInsightOutcomeAfterTheory } from "@/lib/insights/insight-outcome-schedule";
import { TheoryConfidenceMovement } from "@/archived-components/_archived/theories/TheoryConfidenceMovement";
import { TheoryUnderReviewPanel } from "@/archived-components/_archived/theories/TheoryUnderReviewPanel";
import { recordBreakthroughEligibleSurface } from "@/lib/breakthrough/breakthrough-prompt-gate";
import type { Theory, TheoryFeedbackReaction } from "@/types/theory";

const FEEDBACK_OPTIONS: TheoryFeedbackReaction[] = [
  "feels_true",
  "partly_true",
  "not_true",
  "too_obvious",
  "surprising",
];

interface TheoryCardProps {
  theory: Theory;
  defaultExpanded?: boolean;
}

export function TheoryCard({ theory, defaultExpanded = false }: TheoryCardProps) {
  const [expanded, setExpanded] = useState(defaultExpanded);
  const [reaction, setReaction] = useState<TheoryFeedbackReaction | undefined>();
  const [saved, setSaved] = useState(false);
  const viewedRef = useRef(false);
  const revisitedRef = useRef(false);

  useEffect(() => {
    setReaction(getLatestTheoryFeedback(theory.id));
  }, [theory.id]);

  useEffect(() => {
    if (viewedRef.current) return;
    viewedRef.current = true;
    trackTheoryEvent(THEORY_EVENTS.viewed, { theoryId: theory.id, source: theory.source });
  }, [theory.id, theory.source]);

  const toggleExpanded = () => {
    const next = !expanded;
    setExpanded(next);
    if (next) {
      trackTheoryEvent(THEORY_EVENTS.expanded, { theoryId: theory.id, source: theory.source });
    }
    if (!revisitedRef.current && viewedRef.current) {
      revisitedRef.current = true;
      trackTheoryEvent(THEORY_EVENTS.revisited, { theoryId: theory.id, source: theory.source });
      offerInsightOutcomeAfterTheory(theory);
    }
  };

  const submitFeedback = (value: TheoryFeedbackReaction) => {
    saveTheoryFeedback({
      theoryId: theory.id,
      reaction: value,
      statement: theory.statement,
      source: theory.source,
      confidence: theory.confidence,
    });
    setReaction(value);
    setSaved(true);
    if (value === "surprising" || value === "feels_true" || value === "not_true") {
      recordBreakthroughEligibleSurface();
    }
  };

  const showBreakthroughPrompt =
    saved &&
    (reaction === "surprising" || reaction === "feels_true" || reaction === "not_true");

  const uncertainty = buildTheoryUncertaintyFromTheory(theory);

  return (
    <Card className="border-white/5 bg-black/20">
      <CardHeader className="pb-2">
        <p className="text-sm leading-relaxed text-zinc-200">{theory.statement}</p>
        {theory.resolutionNote ? (
          <p className="mt-2 text-xs leading-relaxed text-amber-200/80">{theory.resolutionNote}</p>
        ) : null}
        <TheoryConfidenceMovement
          input={{
            currentConfidence: theory.confidence,
            previousConfidence: theory.previousConfidence,
            delta: theory.confidenceDelta,
            contradictingCount: theory.contradictingEvidenceCount,
            supportingCount: theory.supportingEvidenceCount,
          }}
          className="mt-3"
        />
        <TheoryUnderReviewPanel view={uncertainty} />
        {theory.whatChanged.length > 0 ? (
          <div className="mt-3 rounded-lg border border-white/5 bg-white/[0.02] px-3 py-2">
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">
              {THEORY_PAGE.whatChangedLabel}
            </p>
            <ul className="mt-1 space-y-1">
              {theory.whatChanged.map((line) => (
                <li key={line} className="text-xs leading-relaxed text-zinc-500">
                  {line}
                </li>
              ))}
            </ul>
          </div>
        ) : null}
        <button
          type="button"
          className="mt-3 flex items-center gap-1 text-xs text-zinc-500 hover:text-violet-300"
          onClick={toggleExpanded}
          aria-expanded={expanded}
        >
          <ChevronDown
            className={`h-3.5 w-3.5 transition-transform ${expanded ? "rotate-180" : ""}`}
          />
          {expanded ? "Hide evidence" : "Show evidence"}
        </button>
      </CardHeader>

      {expanded ? (
        <CardContent className="space-y-4 border-t border-white/5 pt-4">
          {theory.supportingEvidence.length > 0 ? (
            <div className="space-y-2">
              <p className="text-[10px] uppercase tracking-wider text-zinc-600">Supporting</p>
              {theory.supportingEvidence.map((q) => (
                <blockquote
                  key={`${theory.id}-s-${q.entryId}`}
                  className="border-l-2 border-violet-400/30 pl-3 text-sm text-zinc-400"
                >
                  <span className="text-[10px] text-zinc-600">{q.dateLabel}</span>
                  <p className="mt-0.5">“{q.quote}”</p>
                </blockquote>
              ))}
            </div>
          ) : null}
          {theory.contradictingEvidence.length > 0 ? (
            <div className="space-y-2">
              <p className="text-[10px] uppercase tracking-wider text-zinc-600">Contradicting</p>
              {theory.contradictingEvidence.map((q) => (
                <blockquote
                  key={`${theory.id}-c-${q.entryId}`}
                  className="border-l-2 border-amber-400/30 pl-3 text-sm text-zinc-400"
                >
                  <span className="text-[10px] text-zinc-600">{q.dateLabel}</span>
                  <p className="mt-0.5">“{q.quote}”</p>
                </blockquote>
              ))}
            </div>
          ) : null}

          {theory.scorecard ? (
            <InsightScorecardPanel scorecard={theory.scorecard} />
          ) : null}

          <div className="space-y-2">
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">Your read</p>
            <div className="flex flex-wrap gap-2">
              {FEEDBACK_OPTIONS.map((option) => (
                <Button
                  key={option}
                  type="button"
                  size="sm"
                  variant={reaction === option ? "secondary" : "ghost"}
                  className="text-xs"
                  onClick={() => submitFeedback(option)}
                >
                  {THEORY_FEEDBACK_LABELS[option]}
                </Button>
              ))}
            </div>
            {saved ? (
              <p className="text-xs text-zinc-600">Saved — helps calibrate what feels useful.</p>
            ) : null}
            {showBreakthroughPrompt ? (
              <TheoryBreakthroughPrompt theory={theory} />
            ) : null}
          </div>
        </CardContent>
      ) : null}
    </Card>
  );
}
