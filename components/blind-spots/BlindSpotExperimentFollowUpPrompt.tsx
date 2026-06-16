"use client";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { BLIND_SPOT_PAGE } from "@/lib/blind-spots/blind-spot-copy";
import { saveExperimentFollowUpAnswer } from "@/lib/blind-spots/blind-spot-experiment-followup";
import type { BlindSpotExperimentCommitment } from "@/types/blind-spot-experiment-loop";
import type { ExperimentFollowUpAnswer } from "@/types/blind-spot-experiment-loop";

interface BlindSpotExperimentFollowUpPromptProps {
  commitment: BlindSpotExperimentCommitment;
  onAnswered: () => void;
}

const OPTIONS: ExperimentFollowUpAnswer[] = [
  "caught_earlier",
  "after_the_fact",
  "no",
  "not_sure",
];

export function BlindSpotExperimentFollowUpPrompt({
  commitment,
  onAnswered,
}: BlindSpotExperimentFollowUpPromptProps) {
  const labels = BLIND_SPOT_PAGE.experimentFollowUpLabels;

  const submit = (answer: ExperimentFollowUpAnswer) => {
    saveExperimentFollowUpAnswer(commitment.commitmentId, answer);
    onAnswered();
  };

  return (
    <Card className="border-violet-500/25 bg-violet-950/10">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-violet-100/90">
          {BLIND_SPOT_PAGE.experimentFollowUpQuestion}
        </CardTitle>
        <p className="mt-1 text-xs leading-relaxed text-zinc-500">
          {BLIND_SPOT_PAGE.experimentFollowUpHelper}
        </p>
        <p className="mt-2 text-xs text-zinc-600">{commitment.headline}</p>
      </CardHeader>
      <CardContent className="flex flex-col gap-2 sm:flex-row sm:flex-wrap">
        {OPTIONS.map((option) => (
          <Button
            key={option}
            type="button"
            size="sm"
            variant="secondary"
            className="justify-start text-left"
            onClick={() => submit(option)}
          >
            {labels[option]}
          </Button>
        ))}
      </CardContent>
    </Card>
  );
}
