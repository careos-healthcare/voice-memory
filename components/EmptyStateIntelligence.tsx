"use client";

import { getEmptyStateMessage } from "@/lib/empty-state-intelligence";
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
    <div className={`space-y-1 px-1 py-1 text-xs leading-relaxed text-zinc-600 ${className ?? ""}`}>
      <p className="font-medium text-zinc-500">{message.headline}</p>
      <p>{message.body}</p>
      {message.hint ? <p className="text-zinc-600">{message.hint}</p> : null}
    </div>
  );
}
