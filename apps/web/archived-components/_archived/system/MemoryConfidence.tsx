"use client";

import { cn } from "@/lib/utils";
import type { ResurfacingFeedbackKind } from "@/lib/resurfacing/resurfacing-feedback";

export type MemoryConfidenceFeedbackHandler = (
  kind: ResurfacingFeedbackKind,
) => void;

export function MemoryConfidence({
  quote,
  subline,
  whySurfaced,
  confidenceLabel,
  onFeedback,
  onNotMe,
  onMissed,
  className,
}: {
  quote: string;
  subline?: string;
  whySurfaced?: string;
  /** e.g. "fairly sure" — omit when low confidence */
  confidenceLabel?: string | null;
  onFeedback?: MemoryConfidenceFeedbackHandler;
  onNotMe?: () => void;
  onMissed?: () => void;
  className?: string;
}) {
  const showQuote = quote.trim().length > 0;
  const handle =
    onFeedback ??
    ((kind: ResurfacingFeedbackKind) => {
      if (kind === "not_me" && onNotMe) onNotMe();
      if ((kind === "missed" || kind === "dismissed") && onMissed) onMissed();
    });

  const feedbackButtons: { kind: ResurfacingFeedbackKind; label: string }[] = [
    { kind: "that_fits", label: "That fits" },
    { kind: "not_me", label: "Not me" },
    { kind: "wrong_topic", label: "Wrong topic" },
    { kind: "wrong_person", label: "Wrong person" },
    { kind: "too_intense", label: "Too intense" },
    { kind: "too_vague", label: "Too vague" },
    { kind: "already_know", label: "Already know this" },
    { kind: "show_less", label: "Show less like this" },
  ];

  const showFeedback = Boolean(onFeedback || onNotMe || onMissed);

  return (
    <div className={cn("space-y-3", className)}>
      {showQuote ? (
        <blockquote className="font-serif text-2xl leading-snug tracking-tight text-zinc-100 sm:text-[1.65rem]">
          {quote}
        </blockquote>
      ) : null}
      {subline ? (
        <p className="text-sm leading-relaxed text-violet-200/85">{subline}</p>
      ) : null}
      {whySurfaced ? (
        <p className="text-xs leading-relaxed text-zinc-400">
          <span className="text-zinc-500">Why this surfaced · </span>
          {whySurfaced}
        </p>
      ) : null}
      {confidenceLabel ? (
        <p className="text-[10px] uppercase tracking-wider text-zinc-500">
          {confidenceLabel}
        </p>
      ) : null}
      {showFeedback && (
        <div
          className="flex flex-wrap items-center gap-2 pt-1"
          role="group"
          aria-label="Is this callback accurate?"
        >
          {feedbackButtons.map(({ kind, label }) => (
            <button
              key={kind}
              type="button"
              onClick={() => handle(kind)}
              className="min-h-11 rounded-full px-3 text-xs text-zinc-500 underline-offset-2 hover:bg-white/5 hover:text-zinc-300 hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-400/50"
            >
              {label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
