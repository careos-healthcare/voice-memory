"use client";

import { useMemo } from "react";

import { buildContinuityStripMessage } from "@/lib/archive/continuity-reinforcement";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ContinuityReinforcementSurface } from "@/types/continuity-reinforcement";
import type { JournalEntry } from "@/types/journal";

interface ContinuityStripProps {
  surface: ContinuityReinforcementSurface;
  className?: string;
  entriesOverride?: JournalEntry[];
}

export function ContinuityStrip({
  surface,
  className = "",
  entriesOverride,
}: ContinuityStripProps) {
  const hydrated = useClientHydrated();
  const entries = entriesOverride ?? (hydrated ? getMemoryEligibleEntries() : []);

  const message = useMemo(() => {
    if (!hydrated) return null;
    return buildContinuityStripMessage(entries, surface);
  }, [hydrated, entries, surface]);

  if (!message) return null;

  return (
    <p
      className={`text-xs leading-relaxed text-zinc-500/95 ${className}`}
      data-testid="continuity-strip"
      data-continuity-surface={surface}
      data-continuity-kind={message.kind}
    >
      {message.text}
    </p>
  );
}
