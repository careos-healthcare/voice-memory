"use client";

import {
  formatConfidenceMovement,
  PERSONAL_THEORY_COPY,
  type ConfidenceMovementInput,
} from "@/lib/theories/theory-confidence-movement";

interface TheoryConfidenceMovementProps {
  input: ConfidenceMovementInput;
  compact?: boolean;
  className?: string;
}

export function TheoryConfidenceMovement({
  input,
  compact = false,
  className = "",
}: TheoryConfidenceMovementProps) {
  const view = formatConfidenceMovement(input);

  return (
    <div
      className={`rounded-lg border border-white/5 bg-white/[0.02] px-3 py-3 ${className}`}
      data-testid="theory-confidence-movement"
    >
      <div className="flex flex-wrap items-baseline gap-x-4 gap-y-1">
        <p className="text-sm font-medium tabular-nums text-zinc-200">
          {view.currentConfidence}%
        </p>
        {view.previousConfidence !== undefined && view.delta !== 0 ? (
          <p className="text-xs text-zinc-500">
            {view.delta > 0 ? "up" : "down"} from {view.previousConfidence}%
          </p>
        ) : null}
        {view.delta !== 0 ? (
          <p
            className={`text-xs font-medium tabular-nums ${
              view.delta > 0 ? "text-violet-300/90" : "text-amber-300/80"
            }`}
          >
            {view.deltaLabel}
          </p>
        ) : null}
      </div>
      {!compact ? (
        <>
          <p className="mt-2 text-xs leading-relaxed text-zinc-500">{view.explanation}</p>
          {view.archiveRead ? (
            <p className="mt-2 text-xs leading-relaxed text-zinc-600">{view.archiveRead}</p>
          ) : null}
          {view.delta > 0 ? (
            <p className="mt-1 text-[11px] text-zinc-600">
              {PERSONAL_THEORY_COPY.archiveMoreConfident}
            </p>
          ) : null}
        </>
      ) : (
        <p className="mt-1 text-xs text-zinc-600">{view.explanation}</p>
      )}
    </div>
  );
}
