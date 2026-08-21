"use client";

import { useCallback, useEffect, useState } from "react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  RETURN_TRIGGER_ATTRIBUTION_DISMISS,
  RETURN_TRIGGER_REASON_LABELS,
  RETURN_TRIGGER_REASON_QUESTION,
} from "@/lib/retention/return-trigger-attribution-copy";
import {
  dismissReturnTriggerReasonPrompt,
  saveReturnTriggerReason,
  shouldShowReturnTriggerReasonPrompt,
} from "@/lib/retention/return-trigger-attribution";
import { RETURN_TRIGGER_REASON_IDS, type ReturnTriggerReasonId } from "@/types/return-trigger-attribution";

interface ReturnTriggerReasonPromptProps {
  className?: string;
}

export function ReturnTriggerReasonPrompt({ className = "" }: ReturnTriggerReasonPromptProps) {
  const [visible, setVisible] = useState(false);

  const refresh = useCallback(() => {
    setVisible(shouldShowReturnTriggerReasonPrompt());
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  if (!visible) return null;

  const submit = (reason: ReturnTriggerReasonId) => {
    saveReturnTriggerReason(reason);
    setVisible(false);
  };

  const dismiss = () => {
    dismissReturnTriggerReasonPrompt();
    setVisible(false);
  };

  return (
    <Card
      className={`border border-amber-500/25 bg-amber-950/15 ${className}`}
      data-testid="return-trigger-reason-prompt"
    >
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-amber-100/90">
          {RETURN_TRIGGER_REASON_QUESTION}
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {RETURN_TRIGGER_REASON_IDS.map((id) => (
          <Button
            key={id}
            type="button"
            size="sm"
            variant="secondary"
            className="h-auto justify-start whitespace-normal py-2 text-left"
            onClick={() => submit(id)}
          >
            {RETURN_TRIGGER_REASON_LABELS[id]}
          </Button>
        ))}
        <button
          type="button"
          onClick={dismiss}
          className="mt-1 text-xs text-zinc-600 hover:text-zinc-400"
        >
          {RETURN_TRIGGER_ATTRIBUTION_DISMISS}
        </button>
      </CardContent>
    </Card>
  );
}
