"use client";

import { useEffect } from "react";
import { Mic } from "lucide-react";
import { useRouter } from "next/navigation";

import { Button } from "@/archived-components/_archived/ui/button";
import {
  CLARITY_DISMISS_CTA,
  CLARITY_PROMPT_BODY,
  CLARITY_PROMPT_TITLE,
  CLARITY_RECORD_CTA,
} from "@/lib/clarity/clarity-copy";
import {
  buildClarityRecordContext,
  storeClarityRecordContext,
} from "@/lib/clarity/clarity-record";
import { buildDirectRecordHref } from "@/lib/capture/direct-record";
import {
  writeDismissClarityPrompt,
  writeTrackClarityPromptShown,
  writeTrackClarityRecordClicked,
} from "@/lib/runtime/write-actions";
import type { ClarityPromptOffer } from "@/types/clarity";

export function SortThisOutAloudPrompt({
  offer,
  anchorSnippet,
}: {
  offer: ClarityPromptOffer;
  anchorSnippet: string;
}) {
  const router = useRouter();

  useEffect(() => {
    writeTrackClarityPromptShown(offer.entryId);
  }, [offer.entryId]);

  return (
    <div className="rounded-xl border border-white/[0.08] bg-zinc-900/35 px-4 py-4">
      <p className="text-sm font-normal text-zinc-300">{CLARITY_PROMPT_TITLE}</p>
      <p className="mt-2 text-sm leading-[1.75] text-zinc-500/90">{CLARITY_PROMPT_BODY}</p>
      <div className="mt-4 flex flex-col gap-2 sm:flex-row sm:items-center">
        <Button
          type="button"
          size="lg"
          className="mobile-touch-target min-h-[3rem]"
          data-primary-cta="recorder"
          onClick={() => {
            const context = buildClarityRecordContext({
              entryId: offer.entryId,
              anchorSnippet,
            });
            storeClarityRecordContext(context);
            writeTrackClarityRecordClicked(offer.entryId);
            router.push(
              buildDirectRecordHref({
                source: "clarity",
                quote: anchorSnippet,
                entryId: offer.entryId,
              }),
            );
          }}
        >
          <Mic className="h-5 w-5" />
          {CLARITY_RECORD_CTA}
        </Button>
        <button
          type="button"
          className="text-sm text-zinc-600 hover:text-zinc-400"
          onClick={() => writeDismissClarityPrompt(offer.entryId)}
        >
          {CLARITY_DISMISS_CTA}
        </button>
      </div>
    </div>
  );
}
