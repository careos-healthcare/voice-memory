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
    <p className={`px-1 py-1 text-xs leading-relaxed text-zinc-600 ${className ?? ""}`}>
      {message.body}
    </p>
  );
}
