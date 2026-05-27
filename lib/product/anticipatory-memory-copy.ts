export type EntryTier = "none" | "one" | "few" | "building" | "rich";

export function getEntryTier(count: number): EntryTier {
  if (count === 0) return "none";
  if (count === 1) return "one";
  if (count < 5) return "few";
  if (count <= 10) return "building";
  return "rich";
}

/** Concrete product promise — specific return behavior, not “AI intelligence”. */
export const MEMORY_PROMISE_CONCRETE =
  "Speak across a few days. When today sounds like something you already said, those words can surface again—in your voice, not as a summary.";

export const RECORD_CTA_LABEL = "Record now";

/** What honestly appears after real reflections — no fabricated previews. */
export const REFLECTION_MILESTONES = [
  {
    after: 1 as const,
    line: "Your reflection is saved here to replay and reopen anytime.",
  },
  {
    after: 2 as const,
    line: "A second reflection lets VoiceMemory compare wording across days.",
  },
  {
    after: 3 as const,
    line: "By three, repeated phrases and return threads can show up before you speak again.",
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
    headline: "Your past words have not arrived yet",
    body: "One short voice reflection starts the archive. After a few real entries, repeated phrases and unfinished threads can return in your own words.",
    showMilestones: true,
  },
  one: {
    tier: "one",
    headline: "One reflection in — the return loop is starting",
    body: "Record again when the same concern or phrase comes back. A second day of real speech is when cross-day wording usually becomes visible.",
    showMilestones: true,
  },
  few: {
    tier: "few",
    headline: "Enough speech for words to repeat",
    body: "Similar phrases, people, and concerns can begin showing up across entries. Return threads and timeline cards fill in as your archive grows.",
    showMilestones: false,
  },
  building: {
    tier: "building",
    headline: "History deep enough to revisit",
    body: "Older reflections can resurface when something you say today connects to words you used before.",
    showMilestones: false,
  },
  rich: {
    tier: "rich",
    headline: "Depth is here",
    body: "Return threads, open loops, and timeline cards draw from your own transcripts—not scores or mood labels.",
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
    return "After 1–3 real reflections, repeated phrases and return threads can appear here.";
  }
  return copy.body;
}
