"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import { readOpenLoopReturnOffer, type OpenLoopReturnOffer } from "@/lib/runtime/read-model";
import {
  writeRecordOpenLoopReturnPromptShown,
  writeTrackOpenLoopReturnPromptEngaged,
  writeTrackOpenLoopReturnPromptShown,
} from "@/lib/runtime/write-actions";

export function OpenLoopReturnPrompt() {
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
      <Link
        href={offer.href}
        className="block text-sm leading-relaxed text-zinc-400 hover:text-zinc-200"
        onClick={() => writeTrackOpenLoopReturnPromptEngaged(offer.openLoopId)}
      >
        {offer.text}
      </Link>
      <button
        type="button"
        className="mt-2 text-xs text-zinc-600 hover:text-zinc-400"
        onClick={() => setOffer(null)}
      >
        Not now
      </button>
    </div>
  );
}
