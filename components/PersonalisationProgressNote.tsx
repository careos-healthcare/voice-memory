"use client";

import { useEffect, useState } from "react";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";

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
  const hydrated = useClientHydrated();
  const [count, setCount] = useState(0);

  useEffect(() => {
    setCount(entryCount ?? getStoredEntryCount());
  }, [entryCount]);

  if (!hydrated || !shouldShowPersonalisationProgress(count)) return null;

  const progress = getPersonalisationProgress(count);
  if (!progress) return null;

  return (
    <p className="px-1 py-1 text-xs leading-relaxed text-zinc-600">{progress.line}</p>
  );
}
