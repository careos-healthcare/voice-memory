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
    headline: "Your memory layer starts with one voice note",
    body: "Talk for up to a minute. VoiceMemory transcribes, surfaces mood and themes, and saves everything on this device — nothing in a cloud journal.",
    hint: "After your first reflection, Weekly and Memory pages begin to take shape.",
  },
  one: {
    tier: "one",
    headline: "One reflection in — patterns need a little time",
    body: "You have a snapshot of mood and themes from today. Add a few more voice notes and recurring people, concerns, and themes will start to appear.",
    hint: "Two or three reflections across different days unlock weekly comparisons.",
  },
  few: {
    tier: "few",
    headline: "Memory intelligence is warming up",
    body: "With a handful of reflections, VoiceMemory can spot themes that repeat and names that come back. Entity memory needs mentions across entries — not just once.",
    hint: "Five reflections is where weekly drift and continuity feel noticeably richer.",
  },
  building: {
    tier: "building",
    headline: "Your longitudinal picture is forming",
    body: "You have enough history for weekly comparisons, emotional drift, and entity continuity. Keep recording — the mirror gets sharper when your words accumulate.",
    hint: "Pro unlocks the full archive if you hit the free 7-entry window.",
  },
  rich: {
    tier: "rich",
    headline: "Deep memory intelligence is active",
    body: "Your archive is long enough for meaningful weekly shifts, recurring patterns, and memory continuity across weeks. Export anytime to keep a portable copy.",
    hint: "Search and weekly intelligence work best when you name people, places, and themes out loud.",
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
      return "1 reflection · early snapshot";
    case "few":
      return `${entryCount} reflections · patterns emerging`;
    case "building":
      return `${entryCount} reflections · weekly intelligence active`;
    case "rich":
      return `${entryCount} reflections · full memory layer`;
  }
}
