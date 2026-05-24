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
    body: "Talk for up to a minute. VoiceMemory saves your words on this device and starts to notice how they change over time.",
    hint: "After your first reflection, Weekly and Memory pages begin to take shape.",
  },
  one: {
    tier: "one",
    headline: "One reflection in",
    body: "You have a snapshot from today. Add a few more voice notes across different days and names and themes will start to come back.",
    hint: "Two or three reflections unlock weekly comparisons.",
  },
  few: {
    tier: "few",
    headline: "Your archive is warming up",
    body: "With a handful of reflections, VoiceMemory can spot themes that repeat and names that come back.",
    hint: "Five reflections is where weekly drift feels noticeably richer.",
  },
  building: {
    tier: "building",
    headline: "Your picture is forming",
    body: "You have enough history for weekly comparisons and emotional drift. Keep recording — the mirror gets sharper when your words accumulate.",
    hint: "Pro unlocks the full archive if you hit the free 7-entry window.",
  },
  rich: {
    tier: "rich",
    headline: "Your archive has depth",
    body: "Your history is long enough for meaningful weekly shifts and quiet callbacks from older entries. Export anytime to keep a portable copy.",
    hint: "Search works best when you name people, places, and themes out loud.",
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
