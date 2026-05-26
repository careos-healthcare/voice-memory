"use client";

import { useEffect, useState } from "react";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { X } from "lucide-react";

import {
  pickCalmComprehensionPrompt,
  recordComprehensionIgnored,
} from "@/lib/onboarding/calm-comprehension";
import type { CalmComprehensionOffer } from "@/types/onboarding-clarity";

export function CalmComprehensionPrompt() {
  const hydrated = useClientHydrated();
  const [offer, setOffer] = useState<CalmComprehensionOffer | null>(null);

  useEffect(() => {
    setOffer(pickCalmComprehensionPrompt());
  }, []);

  if (!hydrated || !offer) return null;

  return (
    <div className="rounded-xl border border-white/[0.06] bg-white/[0.02] px-4 py-3">
      <div className="flex items-start justify-between gap-3">
        <p className="text-sm leading-relaxed text-zinc-500">{offer.text}</p>
        <button
          type="button"
          aria-label="Dismiss"
          className="shrink-0 rounded-full p-1 text-zinc-600 hover:bg-white/5 hover:text-zinc-400"
          onClick={() => {
            recordComprehensionIgnored();
            setOffer(null);
          }}
        >
          <X className="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
  );
}
