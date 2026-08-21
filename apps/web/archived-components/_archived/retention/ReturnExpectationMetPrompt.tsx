"use client";

import { useCallback, useEffect, useState } from "react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  RETURN_EXPECTATION_LABELS,
  RETURN_EXPECTATION_QUESTION,
  RETURN_TRIGGER_ATTRIBUTION_DISMISS,
} from "@/lib/retention/return-trigger-attribution-copy";
import {
  dismissReturnExpectationPrompt,
  saveReturnExpectationMet,
  shouldShowReturnExpectationPrompt,
} from "@/lib/retention/return-trigger-attribution";
import {
  RETURN_EXPECTATION_MET_VALUES,
  type ReturnExpectationMet,
} from "@/types/return-trigger-attribution";

interface ReturnExpectationMetPromptProps {
  className?: string;
}

export function ReturnExpectationMetPrompt({ className = "" }: ReturnExpectationMetPromptProps) {
  const [context, setContext] = useState<ReturnType<typeof shouldShowReturnExpectationPrompt>>(null);

  const refresh = useCallback(() => {
    setContext(shouldShowReturnExpectationPrompt());
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  if (!context) return null;

  const submit = (expectation: ReturnExpectationMet) => {
    saveReturnExpectationMet(expectation, context);
    setContext(null);
  };

  const dismiss = () => {
    dismissReturnExpectationPrompt();
    setContext(null);
  };

  return (
    <Card
      className={`border border-sky-500/25 bg-sky-950/15 ${className}`}
      data-testid="return-expectation-met-prompt"
    >
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-sky-100/90">
          {RETURN_EXPECTATION_QUESTION}
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-wrap gap-2">
        {RETURN_EXPECTATION_MET_VALUES.map((met) => (
          <Button
            key={met}
            type="button"
            size="sm"
            variant="secondary"
            onClick={() => submit(met)}
          >
            {RETURN_EXPECTATION_LABELS[met]}
          </Button>
        ))}
        <button
          type="button"
          onClick={dismiss}
          className="w-full text-left text-xs text-zinc-600 hover:text-zinc-400"
        >
          {RETURN_TRIGGER_ATTRIBUTION_DISMISS}
        </button>
      </CardContent>
    </Card>
  );
}
