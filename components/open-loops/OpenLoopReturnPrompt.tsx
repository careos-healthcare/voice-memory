"use client";

import { useEffect, useState } from "react";
import { Mic } from "lucide-react";

import { Button } from "@/components/ui/button";
import { readOpenLoopReturnOffer, type OpenLoopReturnOffer } from "@/lib/runtime/read-model";
import { buildRecordReturnFromOpenLoop } from "@/lib/reflection/record-return";
import { startRecordReturnFlow } from "@/lib/reflection/start-record-return";
import { recordResurfacingDismissed } from "@/lib/resurfacing/resurfacing-fatigue";
import {
  writeRecordOpenLoopReturnPromptShown,
  writeTrackOpenLoopReturnPromptEngaged,
  writeTrackOpenLoopReturnPromptShown,
} from "@/lib/runtime/write-actions";

export function OpenLoopReturnPrompt({
  onRecordAgain,
}: {
  onRecordAgain?: () => void;
}) {
  const [offer, setOffer] = useState<OpenLoopReturnOffer | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const next = readOpenLoopReturnOffer();
      if (next) {
        writeRecordOpenLoopReturnPromptShown();
        writeTrackOpenLoopReturnPromptShown(next.openLoopId);
      }
      setOffer(next);
    });
    return () => cancelAnimationFrame(id);
  }, []);

  if (!offer) return null;

  return (
    <div className="rounded-xl border border-white/[0.08] bg-zinc-900/40 px-4 py-4">
      <p className="text-sm leading-relaxed text-zinc-400">{offer.text}</p>
      <Button
        type="button"
        size="lg"
        className="mobile-touch-target mt-4 min-h-[3rem] w-full sm:w-auto"
        data-primary-cta="recorder"
        onClick={() => {
          startRecordReturnFlow(
            buildRecordReturnFromOpenLoop({
              openLoopId: offer.openLoopId,
              anchorQuote: offer.text,
              sourceEntryId: offer.sourceEntryId,
            }),
          );
          writeTrackOpenLoopReturnPromptEngaged(offer.openLoopId);
          onRecordAgain?.();
        }}
      >
        <Mic className="h-5 w-5" />
        Record again
      </Button>
      <button
        type="button"
        className="mt-2 text-xs text-zinc-600 hover:text-zinc-400"
        onClick={() => {
          recordResurfacingDismissed(offer.openLoopId);
          setOffer(null);
        }}
      >
        Not now
      </button>
    </div>
  );
}
