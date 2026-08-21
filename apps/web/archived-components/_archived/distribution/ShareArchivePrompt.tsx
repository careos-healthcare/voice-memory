"use client";

import { useEffect, useState } from "react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  trackShareArchiveClicked,
  trackShareArchivePromptSeen,
} from "@/lib/distribution/distribution-events";
import {
  SHARE_ARCHIVE_LABEL,
  activeShareArchiveTrigger,
  canShowShareArchivePrompt,
  markShareArchivePromptSeen,
  shareArchiveMessage,
} from "@/lib/distribution/share-archive-prompt";

type ShareArchivePromptProps = {
  className?: string;
  surface?: string;
};

/** Share Archive — extends referral loop after transformation moments. */
export function ShareArchivePrompt({
  className = "",
  surface = "archive_belief",
}: ShareArchivePromptProps) {
  const [visible, setVisible] = useState(false);
  const trigger = activeShareArchiveTrigger();

  useEffect(() => {
    if (canShowShareArchivePrompt()) {
      setVisible(true);
      markShareArchivePromptSeen();
      trackShareArchivePromptSeen({ trigger: trigger ?? undefined });
    }
  }, [trigger]);

  if (!visible) return null;

  const share = async () => {
    trackShareArchiveClicked({ trigger: trigger ?? undefined });
    const message = shareArchiveMessage();
    if (typeof navigator !== "undefined" && navigator.share) {
      try {
        await navigator.share({
          title: "ArchiveMe",
          text: message,
          url: window.location.origin,
        });
      } catch {
        /* cancelled */
      }
    } else if (typeof navigator !== "undefined" && navigator.clipboard) {
      await navigator.clipboard.writeText(message);
    }
    setVisible(false);
  };

  return (
    <Card
      className={`border-sky-500/25 bg-sky-950/15 ${className}`}
      data-testid="share-archive-prompt"
      data-surface={surface}
    >
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-sky-100/90">
          Know someone who would want their own archive?
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        <p className="text-xs leading-relaxed text-zinc-500">{shareArchiveMessage()}</p>
        <Button type="button" size="sm" onClick={() => void share()}>
          {SHARE_ARCHIVE_LABEL}
        </Button>
        <button
          type="button"
          onClick={() => {
            markShareArchivePromptSeen();
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
