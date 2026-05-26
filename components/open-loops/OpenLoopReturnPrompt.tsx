"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import {
  trackOpenLoopReturnPromptEngaged,
  trackOpenLoopReturnPromptShown,
} from "@/lib/open-loops/open-loop-observation";
import {
  pickOpenLoopReturnOffer,
  recordOpenLoopReturnPromptShown,
} from "@/lib/open-loops/open-loop-return-prompt";
import type { OpenLoopReturnOffer } from "@/lib/open-loops/open-loop-return-prompt";

export function OpenLoopReturnPrompt() {
  const [offer, setOffer] = useState<OpenLoopReturnOffer | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const next = pickOpenLoopReturnOffer();
      if (next) {
        recordOpenLoopReturnPromptShown();
        trackOpenLoopReturnPromptShown(next.openLoopId);
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
        onClick={() => trackOpenLoopReturnPromptEngaged(offer.openLoopId)}
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
