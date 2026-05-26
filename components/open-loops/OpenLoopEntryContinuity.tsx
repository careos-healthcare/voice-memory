"use client";

import Link from "next/link";
import { useEffect, useMemo } from "react";

import {
  trackOpenLoopEntryReopened,
  trackOpenLoopResurfacingShown,
} from "@/lib/open-loops/open-loop-observation";
import {
  getOpenLoopsForEntry,
  pickEntryOpenLoopContinuityLine,
  primaryAnchorPhrase,
} from "@/lib/open-loops/open-loop-storage";
import type { OpenLoop } from "@/types/open-loop";

interface OpenLoopEntryContinuityProps {
  entryId: string;
}

function activeLoop(entryId: string): OpenLoop | undefined {
  return getOpenLoopsForEntry(entryId).find(
    (row) => row.status === "open" || row.status === "softened",
  );
}

/** Max one evidence-backed continuity line on an entry — quote-anchored when possible. */
export function OpenLoopEntryContinuity({ entryId }: OpenLoopEntryContinuityProps) {
  const loop = useMemo(() => activeLoop(entryId), [entryId]);
  const line = useMemo(() => pickEntryOpenLoopContinuityLine(entryId), [entryId, loop?.updatedAt]);

  useEffect(() => {
    if (!line || !loop) return;
    trackOpenLoopResurfacingShown(loop.openLoopId, line);
  }, [line, loop?.openLoopId]);

  if (!line || !loop) return null;

  const anchor = primaryAnchorPhrase(loop);
  const showAnchor = line.includes(anchor) || line.includes(loop.userNextStep.slice(0, 20));

  return (
    <section className="space-y-3 rounded-xl border border-white/[0.08] bg-white/[0.02] px-4 py-4">
      <p className="text-sm leading-relaxed text-zinc-400">{line}</p>
      {!showAnchor && anchor.length >= 12 ? (
        <p className="text-xs leading-relaxed text-zinc-600">
          Thread: &ldquo;{anchor}&rdquo;
        </p>
      ) : null}
      {loop.userNextStep ? (
        <p className="text-xs text-zinc-600">
          Your note: {loop.userNextStep.slice(0, 80)}
          {loop.userNextStep.length > 80 ? "…" : ""}
        </p>
      ) : null}
      <Link
        href={`/entry/${loop.sourceEntryId}`}
        className="text-xs text-zinc-500 hover:text-zinc-300"
        onClick={() => trackOpenLoopEntryReopened(loop.openLoopId, loop.sourceEntryId)}
      >
        Open source reflection
      </Link>
    </section>
  );
}
