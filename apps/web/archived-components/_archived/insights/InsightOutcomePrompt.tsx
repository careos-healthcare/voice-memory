"use client";

import { useCallback, useEffect, useState } from "react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { INSIGHT_OUTCOME_COPY, INSIGHT_OUTCOME_LABELS } from "@/lib/insights/insight-outcome-copy";
import {
  canShowInsightOutcomePrompt,
  dismissInsightOutcomePrompt,
  getPendingInsightOutcomeOffer,
  markInsightOutcomePromptShown,
  saveInsightOutcomeResponse,
} from "@/lib/insights/insight-outcome-storage";
import type { InsightOutcomeResponse } from "@/types/insight-outcome";

export const INSIGHT_OUTCOME_ANALYTICS = {
  promptShown: "insight_outcome_prompt_shown",
  promptAnswered: "insight_outcome_prompt_answered",
  promptDismissed: "insight_outcome_prompt_dismissed",
} as const;

const OUTCOME_OPTIONS: InsightOutcomeResponse[] = [
  "no_change",
  "noticed_pattern",
  "caught_it_earlier",
  "acted_differently",
  "problem_improved",
  "theory_stopped_fitting",
];

interface InsightOutcomePromptProps {
  className?: string;
}

export function InsightOutcomePrompt({ className = "" }: InsightOutcomePromptProps) {
  const [visible, setVisible] = useState(false);

  const refresh = useCallback(() => {
    setVisible(Boolean(getPendingInsightOutcomeOffer()) && canShowInsightOutcomePrompt());
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  useEffect(() => {
    if (!visible) return;
    markInsightOutcomePromptShown();
  }, [visible]);

  if (!visible) return null;

  const submit = (outcome: InsightOutcomeResponse) => {
    saveInsightOutcomeResponse(outcome);
    setVisible(false);
  };

  const dismiss = () => {
    dismissInsightOutcomePrompt();
    setVisible(false);
  };

  return (
    <Card
      className={`border border-teal-500/25 bg-teal-950/10 ${className}`}
      data-testid="insight-outcome-prompt"
    >
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-teal-100/90">
          {INSIGHT_OUTCOME_COPY.question}
        </CardTitle>
        <p className="text-xs leading-relaxed text-zinc-500">{INSIGHT_OUTCOME_COPY.helper}</p>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {OUTCOME_OPTIONS.map((option) => (
          <Button
            key={option}
            type="button"
            size="sm"
            variant="secondary"
            className="justify-start text-left"
            onClick={() => submit(option)}
          >
            {INSIGHT_OUTCOME_LABELS[option]}
          </Button>
        ))}
        <button
          type="button"
          onClick={dismiss}
          className="mt-1 text-xs text-zinc-600 hover:text-zinc-400"
        >
          {INSIGHT_OUTCOME_COPY.dismiss}
        </button>
      </CardContent>
    </Card>
  );
}
