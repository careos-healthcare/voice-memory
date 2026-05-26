"use client";

import { useMemo } from "react";

import { pickEntryOpenLoopContinuityLine } from "@/lib/open-loops/open-loop-storage";

interface OpenLoopEntryContinuityProps {
  entryId: string;
}

/** Max one evidence-backed continuity line on an entry. */
export function OpenLoopEntryContinuity({ entryId }: OpenLoopEntryContinuityProps) {
  const line = useMemo(() => pickEntryOpenLoopContinuityLine(entryId), [entryId]);

  if (!line) return null;

  return (
    <p className="text-sm leading-relaxed text-zinc-500/90">{line}</p>
  );
}
