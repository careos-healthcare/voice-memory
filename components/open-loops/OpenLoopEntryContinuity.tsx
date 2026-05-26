"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";

import { runWhenIdle } from "@/lib/open-loops/open-loop-defer";
import {
  trackOpenLoopEntryReopened,
  trackOpenLoopResurfacingShown,
} from "@/lib/open-loops/open-loop-observation";
import { recordComponentRender } from "@/lib/open-loops/open-loop-performance";
import {
  getOpenLoopsForEntry,
  pickEntryOpenLoopContinuityLine,
  primaryAnchorPhrase,
  OPEN_LOOP_CHANGE_EVENT,
} from "@/lib/open-loops/open-loop-storage";
import type { OpenLoop } from "@/types/open-loop";

interface OpenLoopEntryContinuityProps {
  entryId: string;
}

interface ContinuityPayload {
  loop: OpenLoop;
  line: string;
}

function readContinuityPayload(entryId: string): ContinuityPayload | null {
  const loop = getOpenLoopsForEntry(entryId).find(
    (row) => row.status === "open" || row.status === "softened",
  );
  if (!loop) return null;
  const line = pickEntryOpenLoopContinuityLine(entryId);
  if (!line) return null;
  return { loop, line };
}

/** Deferred continuity line — does not block transcript or prompt paint. */
export function OpenLoopEntryContinuity({ entryId }: OpenLoopEntryContinuityProps) {
  recordComponentRender("OpenLoopEntryContinuity");

  const [payload, setPayload] = useState<ContinuityPayload | null>(null);
  const trackedLineRef = useRef<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    const cancelIdle = runWhenIdle(() => {
      if (cancelled) return;
      setPayload(readContinuityPayload(entryId));
    });

    const onChange = () => {
      runWhenIdle(() => {
        if (cancelled) return;
        setPayload(readContinuityPayload(entryId));
      });
    };

    window.addEventListener(OPEN_LOOP_CHANGE_EVENT, onChange);
    return () => {
      cancelled = true;
      cancelIdle();
      window.removeEventListener(OPEN_LOOP_CHANGE_EVENT, onChange);
    };
  }, [entryId]);

  useEffect(() => {
    if (!payload?.line || !payload.loop) return;
    if (trackedLineRef.current === payload.line) return;
    trackedLineRef.current = payload.line;
    trackOpenLoopResurfacingShown(payload.loop.openLoopId, payload.line);
  }, [payload?.line, payload?.loop?.openLoopId]);

  if (!payload) return null;

  const { loop, line } = payload;
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
