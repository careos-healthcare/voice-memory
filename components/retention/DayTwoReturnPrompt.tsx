"use client";

import { useEffect, useState } from "react";

import { pickDayTwoReturnOffer, type DayTwoReturnOffer } from "@/lib/retention/day-two-return";
import { getMemoryEligibleEntries } from "@/lib/storage";

export function DayTwoReturnPrompt() {
  const [offer, setOffer] = useState<DayTwoReturnOffer | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const entries = getMemoryEligibleEntries();
      setOffer(pickDayTwoReturnOffer(entries));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  if (!offer) return null;

  return (
    <div className="rounded-lg border border-white/[0.06] bg-zinc-900/30 px-4 py-3">
      {offer.note?.evidenceReason ? (
        <p className="text-xs leading-relaxed text-zinc-500">{offer.note.evidenceReason}</p>
      ) : null}
      <p className="text-sm leading-relaxed text-zinc-400">{offer.text}</p>
    </div>
  );
}
