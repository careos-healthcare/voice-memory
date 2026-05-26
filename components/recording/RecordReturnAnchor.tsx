"use client";

import { Mic } from "lucide-react";

import { Button } from "@/components/ui/button";
import { RECORD_RETURN_HEADING } from "@/lib/reflection/record-return";
import type { RecordReturnContext } from "@/types/record-return";

interface RecordReturnAnchorProps {
  context: RecordReturnContext;
  onRecordAgain: () => void;
  compact?: boolean;
}

/** Surfaced quote stays visible; one tap opens the recorder. */
export function RecordReturnAnchor({
  context,
  onRecordAgain,
  compact = false,
}: RecordReturnAnchorProps) {
  return (
    <div
      className={
        compact
          ? "flex w-full flex-col items-center gap-4"
          : "flex w-full max-w-md flex-col items-center gap-5"
      }
    >
      <div className="w-full text-center">
        <p className="text-xs tracking-wide text-zinc-600">{RECORD_RETURN_HEADING}</p>
        <p className="mt-2 text-sm font-normal leading-[1.75] text-zinc-400/95">
          {context.anchorQuote}
        </p>
      </div>
      <Button
        type="button"
        size="lg"
        data-primary-cta="recorder"
        className="mobile-touch-target min-h-[3.25rem] min-w-[13rem] text-base shadow-lg shadow-violet-600/10"
        onClick={onRecordAgain}
      >
        <Mic className="h-5 w-5" />
        Record again
      </Button>
    </div>
  );
}
