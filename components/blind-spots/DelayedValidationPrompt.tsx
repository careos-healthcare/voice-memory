"use client";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { saveDelayedValidationResponse } from "@/lib/blind-spots/delayed-validation";
import { BLIND_SPOT_PAGE } from "@/lib/blind-spots/blind-spot-copy";
import type { DelayedValidationRecord, DelayedValidationResponse } from "@/types/blind-spot-discovery";

interface DelayedValidationPromptProps {
  record: DelayedValidationRecord;
  onAnswered: () => void;
}

const OPTIONS: Array<{ value: DelayedValidationResponse; label: string }> = [
  { value: "changed_mind", label: BLIND_SPOT_PAGE.delayedChangedMind },
  { value: "still_wrong", label: BLIND_SPOT_PAGE.delayedStillWrong },
  { value: "now_accurate", label: BLIND_SPOT_PAGE.delayedNowAccurate },
];

export function DelayedValidationPrompt({ record, onAnswered }: DelayedValidationPromptProps) {
  const submit = (response: DelayedValidationResponse) => {
    saveDelayedValidationResponse(record.id, response);
    onAnswered();
  };

  return (
    <Card className="border-amber-500/20 bg-amber-950/10">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-amber-200/90">
          {BLIND_SPOT_PAGE.delayedValidationPrompt}
        </CardTitle>
        <p className="mt-1 text-xs text-zinc-500">{record.headline}</p>
      </CardHeader>
      <CardContent className="flex flex-wrap gap-2">
        {OPTIONS.map((option) => (
          <Button
            key={option.value}
            type="button"
            size="sm"
            variant="secondary"
            onClick={() => submit(option.value)}
          >
            {option.label}
          </Button>
        ))}
      </CardContent>
    </Card>
  );
}
