"use client";

import { useCallback, useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  CONVERSION_REASON_LABELS,
  CONVERSION_REASON_QUESTION,
  PAYWALL_ATTRIBUTION_DISMISS,
} from "@/lib/billing/paywall-attribution-copy";
import {
  dismissConversionReasonPrompt,
  saveConversionReason,
  shouldShowConversionReasonPrompt,
} from "@/lib/billing/paywall-attribution";
import { CONVERSION_REASON_IDS, type ConversionReasonId } from "@/types/paywall-attribution";

interface ConversionReasonPromptProps {
  className?: string;
  source?: string;
  /** Bump after checkout success + entitlements refresh. */
  refreshKey?: number | boolean;
}

export function ConversionReasonPrompt({
  className = "",
  source,
  refreshKey,
}: ConversionReasonPromptProps) {
  const [visible, setVisible] = useState(false);

  const refresh = useCallback(() => {
    setVisible(shouldShowConversionReasonPrompt());
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh, refreshKey]);

  if (!visible) return null;

  const submit = (reason: ConversionReasonId) => {
    saveConversionReason(reason, { source });
    setVisible(false);
  };

  const dismiss = () => {
    dismissConversionReasonPrompt();
    setVisible(false);
  };

  return (
    <Card
      className={`border-emerald-500/25 bg-emerald-950/15 ${className}`}
      data-testid="conversion-reason-prompt"
    >
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-emerald-100/90">
          {CONVERSION_REASON_QUESTION}
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {CONVERSION_REASON_IDS.map((id) => (
          <Button
            key={id}
            type="button"
            size="sm"
            variant="secondary"
            className="h-auto justify-start whitespace-normal py-2 text-left"
            onClick={() => submit(id)}
          >
            {CONVERSION_REASON_LABELS[id]}
          </Button>
        ))}
        <button
          type="button"
          onClick={dismiss}
          className="mt-1 text-xs text-zinc-600 hover:text-zinc-400"
        >
          {PAYWALL_ATTRIBUTION_DISMISS}
        </button>
      </CardContent>
    </Card>
  );
}
