"use client";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  PAYWALL_ATTRIBUTION_DISMISS,
  PAYWALL_INTEREST_LABELS,
  PAYWALL_INTEREST_QUESTION,
} from "@/lib/billing/paywall-attribution-copy";
import { savePaywallInterestReason } from "@/lib/billing/paywall-attribution";
import { PAYWALL_INTEREST_REASON_IDS, type PaywallInterestReasonId } from "@/types/paywall-attribution";

interface PaywallInterestPromptProps {
  className?: string;
  surface?: string;
  source?: string;
  onDone: () => void;
}

export function PaywallInterestPrompt({
  className = "",
  surface,
  source,
  onDone,
}: PaywallInterestPromptProps) {
  const submit = (reason: PaywallInterestReasonId) => {
    savePaywallInterestReason(reason, { surface, source });
    onDone();
  };

  return (
    <Card
      className={`border-violet-500/25 bg-violet-950/20 ${className}`}
      data-testid="paywall-interest-prompt"
    >
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-violet-100/90">
          {PAYWALL_INTEREST_QUESTION}
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {PAYWALL_INTEREST_REASON_IDS.map((id) => (
          <Button
            key={id}
            type="button"
            size="sm"
            variant="secondary"
            className="h-auto justify-start whitespace-normal py-2 text-left"
            onClick={() => submit(id)}
          >
            {PAYWALL_INTEREST_LABELS[id]}
          </Button>
        ))}
        <button
          type="button"
          onClick={onDone}
          className="mt-1 text-xs text-zinc-600 hover:text-zinc-400"
        >
          {PAYWALL_ATTRIBUTION_DISMISS}
        </button>
      </CardContent>
    </Card>
  );
}
