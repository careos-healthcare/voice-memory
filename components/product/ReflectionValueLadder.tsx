"use client";

import { useEffect, useRef } from "react";

import {
  ARCHIVE_VALUE_STAGE_COPY,
  REFLECTION_VALUE_LADDER,
} from "@/lib/product/archive-value-copy";
import { EVOLVING_UNDERSTANDING_INTRO } from "@/lib/product/evolving-understanding-copy";
import { buildArchiveValueSnapshot } from "@/lib/product/archive-value-progress";
import { trackReflectionLadderSeen } from "@/lib/product/archive-value-metrics";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import type { JournalEntry } from "@/types/journal";

interface ReflectionValueLadderProps {
  className?: string;
  entriesOverride?: JournalEntry[];
}

export function ReflectionValueLadder({
  className = "",
  entriesOverride,
}: ReflectionValueLadderProps) {
  const hydrated = useClientHydrated();
  const seenRef = useRef(false);
  const snapshot = buildArchiveValueSnapshot(entriesOverride);

  useEffect(() => {
    if (!hydrated || seenRef.current) return;
    seenRef.current = true;
    trackReflectionLadderSeen(snapshot.reflectionCount);
  }, [hydrated, snapshot.reflectionCount]);

  if (!hydrated || snapshot.reflectionCount < 1) return null;

  return (
    <div
      className={`rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4 text-left ${className}`}
      data-testid="reflection-value-ladder"
    >
      <p className="text-xs uppercase tracking-wide text-zinc-500">Evidence ladder</p>
      <p className="mt-2 text-xs leading-relaxed text-zinc-600">
        {EVOLVING_UNDERSTANDING_INTRO.body}
      </p>
      <ul className="mt-3 space-y-2 text-sm">
        {REFLECTION_VALUE_LADDER.map((step) => {
          const active = snapshot.reflectionCount >= step.reflections;
          const current =
            snapshot.stage === step.stage ||
            (snapshot.reflectionCount === step.reflections && active);
          return (
            <li
              key={step.reflections}
              className={`flex gap-3 ${active ? "text-zinc-200" : "text-zinc-600"}`}
            >
              <span className="w-16 shrink-0 font-medium tabular-nums">
                {step.reflections} moment{step.reflections === 1 ? "" : "s"}
              </span>
              <span className={current ? "text-violet-200/90" : undefined}>
                → {ARCHIVE_VALUE_STAGE_COPY[step.stage].ladderLabel}
              </span>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
