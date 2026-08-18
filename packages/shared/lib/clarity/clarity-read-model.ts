import { getEntry } from "@/lib/storage";
import {
  detectThinkingOutLoudSignals,
  qualifiesForClarityPrompt,
} from "@/lib/clarity/thinking-out-loud-signals";
import {
  displayThoughtPatterns,
  thoughtPatternsStrongEnough,
} from "@/lib/clarity/thought-patterns";
import {
  isClarityPromptDismissedInStore,
  readThoughtPatternsForEntryFromStore,
} from "@/lib/clarity/clarity-storage";
import type { ClarityPromptOffer, CirclingThoughtsDisplay } from "@/types/clarity";

export function readThinkingOutLoudSignalsForEntry(entryId: string) {
  const entry = getEntry(entryId);
  if (!entry?.transcript?.trim()) return null;
  return detectThinkingOutLoudSignals(entry.transcript);
}

export function readClarityPromptOffer(entryId: string): ClarityPromptOffer | null {
  if (isClarityPromptDismissedInStore(entryId)) return null;
  const signals = readThinkingOutLoudSignalsForEntry(entryId);
  if (!signals || !qualifiesForClarityPrompt(signals)) return null;
  return { entryId, signals };
}

export function readCirclingThoughtsForEntry(entryId: string): CirclingThoughtsDisplay | null {
  const patterns = readThoughtPatternsForEntryFromStore(entryId);
  const items = displayThoughtPatterns(patterns);
  if (!thoughtPatternsStrongEnough(items)) return null;
  return { entryId, items };
}
