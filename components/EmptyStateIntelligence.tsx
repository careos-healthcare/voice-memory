"use client";

import { getEmptyStateMessage, getTierProgressLabel } from "@/lib/empty-state-intelligence";
import { getStoredEntryCount } from "@/lib/storage";

interface EmptyStateIntelligenceProps {
  entryCount?: number;
  className?: string;
  hideWhenRich?: boolean;
}

export function EmptyStateIntelligence({
  entryCount,
  className,
  hideWhenRich = false,
}: EmptyStateIntelligenceProps) {
  const count =
    entryCount ??
    (typeof window !== "undefined" ? getStoredEntryCount() : 0);
  const message = getEmptyStateMessage(count);

  if (hideWhenRich && message.tier === "rich") return null;

  return (
    <div
      className={`rounded-2xl border border-violet-400/15 bg-violet-500/5 px-4 py-4 ${className ?? ""}`}
    >
      <p className="text-xs font-medium uppercase tracking-wider text-violet-300/90">
        {getTierProgressLabel(count)}
      </p>
      <p className="mt-2 text-sm font-medium text-white">{message.headline}</p>
      <p className="mt-2 text-sm leading-relaxed text-zinc-400">{message.body}</p>
      {message.hint ? (
        <p className="mt-2 text-xs leading-relaxed text-zinc-600">{message.hint}</p>
      ) : null}
    </div>
  );
}
