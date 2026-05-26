"use client";

import { useCallback, useMemo, useState } from "react";

import {
  dismissFreshEntryQuietMode,
  isFreshEntryQuietMode,
} from "@/lib/refinement/entry-quiet-state";
import type { JournalEntry } from "@/types/journal";

export function useFreshEntryQuietMode(
  entry: JournalEntry | undefined,
  isRevisit: boolean,
  presentationEnabled = false,
) {
  const [expanded, setExpanded] = useState(false);

  const freshQuiet = useMemo(() => {
    if (!presentationEnabled || !entry || isRevisit || expanded) return false;
    return isFreshEntryQuietMode(entry.id, entry.createdAt);
  }, [presentationEnabled, entry, isRevisit, expanded]);

  const expandFreshQuiet = useCallback(() => {
    if (!entry) return;
    dismissFreshEntryQuietMode(entry.id);
    setExpanded(true);
  }, [entry]);

  return { freshQuiet, expandFreshQuiet };
}
