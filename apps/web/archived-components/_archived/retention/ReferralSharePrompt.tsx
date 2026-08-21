"use client";

import { useEffect, useState } from "react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  REFERRAL_SHARE_TEXT,
  canShowReferralSharePrompt,
  dismissReferralSharePrompt,
  markReferralSharePromptSeen,
  trackReferralShareClicked,
} from "@/lib/retention/referral-share-prompt";

interface ReferralSharePromptProps {
  className?: string;
  surface?: string;
}

export function ReferralSharePrompt({
  className = "",
  surface = "archive_belief",
}: ReferralSharePromptProps) {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (canShowReferralSharePrompt()) {
      setVisible(true);
      markReferralSharePromptSeen();
    }
  }, []);

  if (!visible) return null;

  const share = async () => {
    trackReferralShareClicked();
    if (typeof navigator !== "undefined" && navigator.share) {
      try {
        await navigator.share({
          title: "ArchiveMe",
          text: REFERRAL_SHARE_TEXT,
          url: typeof window !== "undefined" ? window.location.origin : undefined,
        });
      } catch {
        /* user cancelled */
      }
    } else if (typeof navigator !== "undefined" && navigator.clipboard) {
      await navigator.clipboard.writeText(REFERRAL_SHARE_TEXT);
    }
    setVisible(false);
  };

  return (
    <Card
      className={`border-sky-500/25 bg-sky-950/15 ${className}`}
      data-testid="referral-share-prompt"
      data-surface={surface}
    >
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-sky-100/90">
          Know someone who would want to see what keeps repeating?
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        <p className="text-xs leading-relaxed text-zinc-500">{REFERRAL_SHARE_TEXT}</p>
        <Button type="button" size="sm" onClick={() => void share()}>
          Share ArchiveMe
        </Button>
        <button
          type="button"
          onClick={() => {
            dismissReferralSharePrompt();
            setVisible(false);
          }}
          className="text-xs text-zinc-600 hover:text-zinc-400"
        >
          Not now
        </button>
      </CardContent>
    </Card>
  );
}
