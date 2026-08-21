"use client";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  PAYWALL_ATTRIBUTION_DISMISS,
  PAYWALL_REJECTION_LABELS,
  PAYWALL_REJECTION_QUESTION,
} from "@/lib/billing/paywall-attribution-copy";
import { savePaywallRejectionReason } from "@/lib/billing/paywall-attribution";
import { PAYWALL_REJECTION_REASON_IDS, type PaywallRejectionReasonId } from "@/types/paywall-attribution";

interface PaywallRejectionPromptProps {
  className?: string;
  surface?: string;
  source?: string;
  onDone?: () => void;
}

export function PaywallRejectionPrompt({
  className = "",
  surface,
  source,
  onDone,
}: PaywallRejectionPromptProps) {
  const submit = (reason: PaywallRejectionReasonId) => {
    savePaywallRejectionReason(reason, { surface, source });
    onDone?.();
  };

  const dismiss = () => {
    onDone?.();
  };

  return (
    <Card
      className={`border-amber-500/25 bg-amber-950/15 ${className}`}
      data-testid="paywall-rejection-prompt"
    >
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-amber-100/90">
          {PAYWALL_REJECTION_QUESTION}
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {PAYWALL_REJECTION_REASON_IDS.map((id) => (
          <Button
            key={id}
            type="button"
            size="sm"
            variant="secondary"
            className="h-auto justify-start whitespace-normal py-2 text-left"
            onClick={() => submit(id)}
          >
            {PAYWALL_REJECTION_LABELS[id]}
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
