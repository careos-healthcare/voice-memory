export type EntryTier = "none" | "one" | "few" | "building" | "rich";

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
    body: "Add a few more across different days and VoiceMemory will start noticing patterns.",
  },
  few: {
    tier: "few",
    headline: "Patterns forming",
    body: "A handful of reflections is enough for themes, moods, and names to recur.",
  },
  building: {
    tier: "building",
    headline: "Your memory layer is growing",
    body: "Enough history for weekly comparisons and quiet callbacks from older reflections.",
  },
  rich: {
    tier: "rich",
    headline: "Depth is here",
    body: "Your history is long enough for meaningful shifts and recurring concerns worth revisiting.",
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
