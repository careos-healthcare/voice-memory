"use client";

import { useEffect, useMemo } from "react";

import { trackOpenLoopResurfacingShown } from "@/lib/open-loops/open-loop-observation";
import {
  getOpenLoopsForEntry,
  pickEntryOpenLoopContinuityLine,
} from "@/lib/open-loops/open-loop-storage";

interface OpenLoopEntryContinuityProps {
  entryId: string;
}

/** Max one evidence-backed continuity line on an entry. */
export function OpenLoopEntryContinuity({ entryId }: OpenLoopEntryContinuityProps) {
  const line = useMemo(() => pickEntryOpenLoopContinuityLine(entryId), [entryId]);

  useEffect(() => {
    if (!line) return;
    const loop = getOpenLoopsForEntry(entryId).find(
      (row) => row.status === "open" || row.status === "softened",
    );
    if (loop) trackOpenLoopResurfacingShown(loop.openLoopId, line);
  }, [line, entryId]);

  if (!line) return null;

  return (
    <p className="text-sm leading-relaxed text-zinc-500/90">{line}</p>
  );
}
