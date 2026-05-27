export type EntryTier = "none" | "one" | "few" | "building" | "rich";

export function getEntryTier(count: number): EntryTier {
  if (count === 0) return "none";
  if (count === 1) return "one";
  if (count < 5) return "few";
  if (count <= 10) return "building";
  return "rich";
}

export const RECORD_CTA_LABEL = "Record now";

/** What honestly appears after real reflections — no fabricated previews. */
export const REFLECTION_MILESTONES = [
  {
    after: 1 as const,
    line: "Saved here to replay.",
  },
  {
    after: 2 as const,
    line: "A second entry — VoiceMemory can compare your words.",
  },
  {
    after: 3 as const,
    line: "By three, what repeats may show up before you speak.",
  },
] as const;

export interface AnticipatoryEmptyCopy {
  tier: EntryTier;
  headline: string;
  body: string;
  showMilestones: boolean;
}

const ANTICIPATORY_BY_TIER: Record<EntryTier, AnticipatoryEmptyCopy> = {
  none: {
    tier: "none",
    headline: "Nothing has returned yet",
    body: "Say it once. When you repeat yourself across days, it may come back.",
    showMilestones: true,
  },
  one: {
    tier: "one",
    headline: "One entry in",
    body: "Say one more when the same words come back.",
    showMilestones: true,
  },
  few: {
    tier: "few",
    headline: "Words are starting to repeat",
    body: "What you said before may surface again.",
    showMilestones: false,
  },
  building: {
    tier: "building",
    headline: "Something is returning",
    body: "Older words can meet what you say today.",
    showMilestones: false,
  },
  rich: {
    tier: "rich",
    headline: "Your words keep meeting each other",
    body: "Returns draw from what you actually said.",
    showMilestones: false,
  },
};

export function getAnticipatoryEmptyCopy(entryCount: number): AnticipatoryEmptyCopy {
  return ANTICIPATORY_BY_TIER[getEntryTier(entryCount)];
}

/** Short line for inline hints (habit loop, cards). */
export function anticipatoryHint(entryCount: number): string {
  const copy = getAnticipatoryEmptyCopy(entryCount);
  if (copy.tier === "none") {
    return "After a few entries, what repeats may appear here.";
  }
  return copy.body;
}
