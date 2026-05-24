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
    headline: "Start with one voice note",
    body: "Talk for up to a minute. Your words stay on this device.",
  },
  one: {
    tier: "one",
    headline: "One reflection in",
    body: "Add a few more across different days and older words will start to link up.",
  },
  few: {
    tier: "few",
    headline: "Building slowly",
    body: "A handful of reflections is enough for themes and names to come back.",
  },
  building: {
    tier: "building",
    headline: "Your picture is forming",
    body: "You have enough history for weekly comparisons and quiet callbacks from older entries.",
  },
  rich: {
    tier: "rich",
    headline: "Depth is here",
    body: "Your history is long enough for meaningful shifts and older words worth reopening.",
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
