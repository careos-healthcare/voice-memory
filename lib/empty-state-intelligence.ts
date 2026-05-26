export type EntryTier = "none" | "one" | "few" | "building" | "rich";

import { WEDGE_RESURFACING } from "@/lib/product-copy";

export function getEntryTier(count: number): EntryTier {
  if (count === 0) return "none";
  if (count === 1) return "one";
  if (count < 5) return "few";
  if (count <= 10) return "building";
  return "rich";
}

export interface EmptyStateMessage {
  tier: EntryTier;
  headline: string;
  body: string;
  hint?: string;
}

const MESSAGES: Record<EntryTier, EmptyStateMessage> = {
  none: {
    tier: "none",
    headline: "Start with one voice reflection",
    body: "Talk naturally for a minute. Your words stay on this device.",
  },
  one: {
    tier: "one",
    headline: "One reflection in",
    body: "Add a few more across different days and older words may return when they match again.",
  },
  few: {
    tier: "few",
    headline: "Words starting to repeat",
    body: "A handful of reflections is enough for similar phrases, moods, and concerns to show up again.",
  },
  building: {
    tier: "building",
    headline: "Enough history to revisit",
    body: "Older reflections can return when something you say today connects to words you used before.",
  },
  rich: {
    tier: "rich",
    headline: "Depth is here",
    body: `${WEDGE_RESURFACING.forgottenPatterns} ${WEDGE_RESURFACING.ownVoicePattern}`,
  },
};

export function getEmptyStateMessage(entryCount: number): EmptyStateMessage {
  return MESSAGES[getEntryTier(entryCount)];
}

export function getTierProgressLabel(entryCount: number): string {
  const tier = getEntryTier(entryCount);
  switch (tier) {
    case "none":
      return "0 reflections";
    case "one":
      return "1 reflection";
    case "few":
      return `${entryCount} reflections`;
    case "building":
      return `${entryCount} reflections`;
    case "rich":
      return `${entryCount} reflections`;
  }
}
