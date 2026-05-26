"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import {
  OPEN_LOOP_CLOSURE_PLACEHOLDER,
  OPEN_LOOP_CLOSURE_QUESTION,
  OPEN_LOOP_CLOSE_LABEL,
  OPEN_LOOP_EARLIER_MOMENTS,
  OPEN_LOOP_KEEP_OPEN_LABEL,
  OPEN_LOOP_SOFTEN_LABEL,
} from "@/lib/open-loops/open-loop-copy";
import {
  trackOpenLoopEntryReopened,
  trackOpenLoopResurfacingShown,
} from "@/lib/open-loops/open-loop-observation";
import {
  closeOpenLoop,
  updateOpenLoopStatus,
} from "@/lib/open-loops/open-loop-storage";
import { formatEntryDate } from "@/lib/utils";
import type { OpenLoopPresentation } from "@/types/open-loop";

interface OpenLoopCardProps {
  loop: OpenLoopPresentation;
  compact?: boolean;
}

export function OpenLoopCard({ loop, compact = false }: OpenLoopCardProps) {
  const [closing, setClosing] = useState(false);
  const [closureNote, setClosureNote] = useState("");

  useEffect(() => {
    if (loop.resurfacingLine) {
      trackOpenLoopResurfacingShown(loop.openLoopId, loop.resurfacingLine);
    }
  }, [loop.openLoopId, loop.resurfacingLine]);

  const earlierMoments =
    loop.connectedMoments.length > 1
      ? loop.connectedMoments.slice(0, -1)
      : loop.connectedMoments.filter((moment) => moment.entryId !== loop.sourceEntryId);
  const showEarlier = !compact && earlierMoments.length > 0 ? earlierMoments : [];

  const handleClose = () => {
    closeOpenLoop(loop.openLoopId, closureNote);
    setClosing(false);
    setClosureNote("");
  };

  return (
    <article className="space-y-6 py-2">
      {loop.resurfacingLine ? (
        <p className="text-sm leading-relaxed text-zinc-500">{loop.resurfacingLine}</p>
      ) : null}

      <div className="space-y-4">
        <p className="text-base font-normal leading-relaxed text-zinc-200">
          {loop.userNextStep}
        </p>
        <p className="text-sm leading-relaxed text-zinc-600">
          &ldquo;{loop.strongestAnchorPhrase}&rdquo;
        </p>
        <p className="text-xs text-zinc-700">
          Last mentioned{" "}
          {loop.sourceEntryDateLabel ?? formatEntryDate(loop.lastMentionedAt)}
        </p>
      </div>

      {!compact && showEarlier.length > 0 ? (
        <section className="space-y-4 pt-2">
          <h3 className="text-xs font-normal tracking-wide text-zinc-600">
            {OPEN_LOOP_EARLIER_MOMENTS}
          </h3>
          <ul className="space-y-5">
            {showEarlier.map((moment) => (
              <li key={`${moment.entryId}-${moment.recordedAt}`} className="space-y-1.5">
                <p className="text-xs text-zinc-700">{formatEntryDate(moment.recordedAt)}</p>
                <p className="text-sm leading-relaxed text-zinc-500">
                  &ldquo;{moment.quoteFragment}&rdquo;
                </p>
                {moment.emotionalLabel ? (
                  <p className="text-xs text-zinc-700">{moment.emotionalLabel}</p>
                ) : null}
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {!compact ? (
        <div className="space-y-4 pt-2">
          {closing ? (
            <div className="space-y-3">
              <p className="text-sm text-zinc-500">{OPEN_LOOP_CLOSURE_QUESTION}</p>
              <textarea
                value={closureNote}
                onChange={(event) => setClosureNote(event.target.value)}
                placeholder={OPEN_LOOP_CLOSURE_PLACEHOLDER}
                rows={2}
                className="w-full resize-none rounded-lg border border-white/[0.06] bg-transparent px-0 py-1 text-sm leading-relaxed text-zinc-400 placeholder:text-zinc-700 focus:border-white/[0.1] focus:outline-none"
              />
              <div className="flex flex-wrap gap-4 text-sm">
                <button
                  type="button"
                  className="text-zinc-500 hover:text-zinc-300"
                  onClick={handleClose}
                >
                  {OPEN_LOOP_CLOSE_LABEL}
                </button>
                <button
                  type="button"
                  className="text-zinc-700 hover:text-zinc-500"
                  onClick={() => setClosing(false)}
                >
                  Cancel
                </button>
              </div>
            </div>
          ) : (
            <div className="flex flex-wrap gap-x-5 gap-y-2 text-sm text-zinc-600">
              <Link
                href={`/entry/${loop.sourceEntryId}`}
                className="hover:text-zinc-400"
                onClick={() =>
                  trackOpenLoopEntryReopened(loop.openLoopId, loop.sourceEntryId)
                }
              >
                Open reflection
              </Link>
              {loop.status === "open" ? (
                <button
                  type="button"
                  className="hover:text-zinc-400"
                  onClick={() => updateOpenLoopStatus(loop.openLoopId, "softened")}
                >
                  {OPEN_LOOP_SOFTEN_LABEL}
                </button>
              ) : (
                <button
                  type="button"
                  className="hover:text-zinc-400"
                  onClick={() => updateOpenLoopStatus(loop.openLoopId, "open")}
                >
                  {OPEN_LOOP_KEEP_OPEN_LABEL}
                </button>
              )}
              <button
                type="button"
                className="hover:text-zinc-400"
                onClick={() => setClosing(true)}
              >
                {OPEN_LOOP_CLOSE_LABEL}
              </button>
            </div>
          )}
        </div>
      ) : (
        <Link
          href={`/entry/${loop.sourceEntryId}`}
          className="text-sm text-zinc-600 hover:text-zinc-400"
          onClick={() =>
            trackOpenLoopEntryReopened(loop.openLoopId, loop.sourceEntryId)
          }
        >
          Open reflection
        </Link>
      )}
    </article>
  );
}
