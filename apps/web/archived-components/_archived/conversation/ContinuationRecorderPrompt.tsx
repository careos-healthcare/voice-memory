"use client";

import { useEffect } from "react";
import { Mic } from "lucide-react";

import { Button } from "@/archived-components/_archived/ui/button";
import {
  peekContinuationMeta,
  trackContinuationSeen,
  trackContinuationStarted,
} from "@/lib/conversation/continuation-loops";

interface ContinuationRecorderPromptProps {
  text: string;
  onContinue: () => void;
}

/** One quiet line and one Continue button — unfinished conversation, not coaching. */
export function ContinuationRecorderPrompt({
  text,
  onContinue,
}: ContinuationRecorderPromptProps) {
  useEffect(() => {
    const meta = peekContinuationMeta();
    trackContinuationSeen(meta?.promptId ?? "recorder-continuation", meta?.noteId);
  }, [text]);

  return (
    <div className="flex flex-col items-center gap-5">
      <p className="max-w-sm text-center text-sm font-normal leading-[1.75] text-zinc-500/90">
        {text}
      </p>
      <Button
        size="lg"
        onClick={() => {
          const meta = peekContinuationMeta();
          trackContinuationStarted(meta?.promptId ?? "recorder-continuation", meta?.noteId);
          onContinue();
        }}
      >
        <Mic className="h-5 w-5" />
        Continue
      </Button>
    </div>
  );
}
