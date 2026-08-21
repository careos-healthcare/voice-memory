"use client";

import { useCallback, useEffect, useState } from "react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  ORGANIC_REFERRAL_DISMISS,
  ORGANIC_REFERRAL_QUESTION,
  ORGANIC_REFERRAL_REASON_LABELS,
  ORGANIC_REFERRAL_REASON_QUESTION,
  ORGANIC_REFERRAL_STATUS_LABELS,
  REFERRAL_BLOCKER_LABELS,
  REFERRAL_BLOCKER_QUESTION,
} from "@/lib/retention/organic-referral-copy";
import {
  canShowOrganicReferralPrompt,
  dismissOrganicReferralFollowUp,
  dismissOrganicReferralPrompt,
  saveOrganicReferralReason,
  saveOrganicReferralStatus,
  saveReferralBlocker,
  shouldShowOrganicReferralFollowUp,
} from "@/lib/retention/organic-referral";
import {
  ORGANIC_REFERRAL_REASON_IDS,
  ORGANIC_REFERRAL_STATUS_IDS,
  REFERRAL_BLOCKER_IDS,
  type OrganicReferralReasonId,
  type OrganicReferralStatusId,
  type ReferralBlockerId,
} from "@/types/organic-referral";
import type { JournalEntry } from "@/types/journal";

type Phase = "status" | "referral_reason" | "referral_blocker" | null;

interface OrganicReferralPromptProps {
  className?: string;
  entriesOverride?: JournalEntry[];
}

export function OrganicReferralPrompt({
  className = "",
  entriesOverride,
}: OrganicReferralPromptProps) {
  const [phase, setPhase] = useState<Phase>(null);
  const [followUpContext, setFollowUpContext] = useState<ReturnType<
    typeof shouldShowOrganicReferralFollowUp
  >>(null);

  const refresh = useCallback(() => {
    const pending = shouldShowOrganicReferralFollowUp();
    if (pending) {
      setFollowUpContext(pending);
      setPhase(pending.kind);
      return;
    }
    if (canShowOrganicReferralPrompt(Date.now(), entriesOverride)) {
      setPhase("status");
      return;
    }
    setPhase(null);
  }, [entriesOverride]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  if (!phase) return null;

  if ((phase === "referral_reason" || phase === "referral_blocker") && followUpContext) {
    const isReason = phase === "referral_reason";
    const title = isReason ? ORGANIC_REFERRAL_REASON_QUESTION : REFERRAL_BLOCKER_QUESTION;
    const testId = isReason
      ? "organic-referral-reason-prompt"
      : "organic-referral-blocker-prompt";

    return (
      <Card
        className={`border-sky-500/25 bg-sky-950/15 ${className}`}
        data-testid={testId}
      >
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-medium text-sky-100/90">{title}</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-2">
          {(isReason ? ORGANIC_REFERRAL_REASON_IDS : REFERRAL_BLOCKER_IDS).map((id) => (
            <Button
              key={id}
              type="button"
              size="sm"
              variant="secondary"
              className="h-auto justify-start whitespace-normal py-2 text-left"
              onClick={() => {
                if (isReason) {
                  saveOrganicReferralReason(id as OrganicReferralReasonId, followUpContext.attributionId);
                } else {
                  saveReferralBlocker(id as ReferralBlockerId, followUpContext.attributionId);
                }
                setPhase(null);
                setFollowUpContext(null);
              }}
            >
              {isReason
                ? ORGANIC_REFERRAL_REASON_LABELS[id as OrganicReferralReasonId]
                : REFERRAL_BLOCKER_LABELS[id as ReferralBlockerId]}
            </Button>
          ))}
          <button
            type="button"
            onClick={() => {
              dismissOrganicReferralFollowUp();
              setPhase(null);
              setFollowUpContext(null);
            }}
            className="mt-1 text-xs text-zinc-600 hover:text-zinc-400"
          >
            {ORGANIC_REFERRAL_DISMISS}
          </button>
        </CardContent>
      </Card>
    );
  }

  const submitStatus = (status: OrganicReferralStatusId) => {
    saveOrganicReferralStatus(status, entriesOverride);
    const pending = shouldShowOrganicReferralFollowUp();
    if (pending && (status === "yes" || status === "no")) {
      setFollowUpContext(pending);
      setPhase(pending.kind);
      return;
    }
    setPhase(null);
  };

  const dismiss = () => {
    dismissOrganicReferralPrompt();
    setPhase(null);
  };

  return (
    <Card
      className={`border-sky-500/30 bg-sky-950/10 ${className}`}
      data-testid="organic-referral-prompt"
    >
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-sky-100/90">
          {ORGANIC_REFERRAL_QUESTION}
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {ORGANIC_REFERRAL_STATUS_IDS.map((id) => (
          <Button
            key={id}
            type="button"
            size="sm"
            variant="secondary"
            className="h-auto justify-start py-2 text-left"
            onClick={() => submitStatus(id)}
          >
            {ORGANIC_REFERRAL_STATUS_LABELS[id]}
          </Button>
        ))}
        <button
          type="button"
          onClick={dismiss}
          className="mt-1 text-xs text-zinc-600 hover:text-zinc-400"
        >
          {ORGANIC_REFERRAL_DISMISS}
        </button>
      </CardContent>
    </Card>
  );
}
