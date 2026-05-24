"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import {
  continueRoundupThought,
  isRoundupItemSaved,
  ROUNDUP_SAVED_COPY,
  saveRoundupToReturnTo,
} from "@/lib/roundups/roundup-continuation";
import type { RoundupContinuationItem } from "@/types/reflective-roundup";

export function RoundupContinuationActions({
  item,
  periodSlug,
}: {
  item: RoundupContinuationItem;
  periodSlug?: string;
}) {
  const router = useRouter();
  const [saved, setSaved] = useState(() => isRoundupItemSaved(item.id));

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap gap-x-4 gap-y-1">
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="h-auto px-0 text-xs text-zinc-500 hover:bg-transparent hover:text-zinc-300"
          onClick={() => {
            continueRoundupThought(item, periodSlug);
            router.push("/#recorder");
          }}
        >
          Continue this thought
        </Button>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="h-auto px-0 text-xs text-zinc-500 hover:bg-transparent hover:text-zinc-300"
          onClick={() => {
            saveRoundupToReturnTo(item, periodSlug);
            setSaved(true);
          }}
        >
          Save to return to
        </Button>
      </div>
      {saved ? (
        <p className="text-xs leading-relaxed text-zinc-600/90">{ROUNDUP_SAVED_COPY}</p>
      ) : null}
    </div>
  );
}
