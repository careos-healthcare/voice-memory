"use client";

import {
  getPersonalisationProgress,
  shouldShowPersonalisationProgress,
} from "@/lib/activation-guidance";
import { getStoredEntryCount } from "@/lib/storage";

export function PersonalisationProgressNote({
  entryCount,
}: {
  entryCount?: number;
}) {
  const count =
    entryCount ??
    (typeof window !== "undefined" ? getStoredEntryCount() : 0);

  if (!shouldShowPersonalisationProgress(count)) return null;

  const progress = getPersonalisationProgress(count);
  if (!progress) return null;

  return (
    <p className="px-1 py-1 text-xs leading-relaxed text-zinc-600">{progress.line}</p>
  );
}
