"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import { pickGentleReturnPrompt } from "@/lib/retention/gentle-return-prompts";
import {
  markReturnPromptPending,
  trackReturnPromptOpened,
} from "@/lib/retention/first-week-observation";
import { recordGentlePromptEngaged, recordGentlePromptIgnored } from "@/lib/retention/first-week";
import type { GentleReturnPromptOffer } from "@/types/first-week-retention";

export function GentleReturnPrompt() {
  const [offer, setOffer] = useState<GentleReturnPromptOffer | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setOffer(pickGentleReturnPrompt());
    });
    return () => cancelAnimationFrame(id);
  }, []);

  if (!offer) return null;

  const onOpen = () => {
    recordGentlePromptEngaged();
    trackReturnPromptOpened(offer.id);
    if (offer.href?.startsWith("/")) {
      markReturnPromptPending(offer.id);
    }
  };

  const onDismiss = () => {
    recordGentlePromptIgnored();
    setOffer(null);
  };

  const body = (
    <p className="text-sm leading-relaxed text-zinc-400">{offer.text}</p>
  );

  return (
    <div className="rounded-lg border border-white/[0.06] bg-zinc-900/30 px-4 py-3">
      {offer.href ? (
        <Link href={offer.href} onClick={onOpen} className="block hover:text-zinc-300">
          {body}
        </Link>
      ) : (
        body
      )}
      <button
        type="button"
        onClick={onDismiss}
        className="mt-2 text-xs text-zinc-600 hover:text-zinc-400"
      >
        Not now
      </button>
    </div>
  );
}
