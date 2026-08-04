import type { ArchiveMilestoneTypeId } from "@/types/archive-milestone";

export const ARCHIVE_MILESTONE_HISTORY_HEADLINE = "Archive History";

export const ARCHIVE_LATEST_MILESTONE_LABEL = "Latest milestone";

export const ARCHIVE_MILESTONE_RETURN_EYEBROW = "While you were away";

export const ARCHIVE_MILESTONE_RETURN_HEADLINE = "The archive reached a milestone";

export const ARCHIVE_MILESTONE_FEED_HEADLINE = "Recent archive history";

export const ARCHIVE_MILESTONE_WHY_LABEL = "Why this matters";

export const MILESTONE_TITLES: Record<ArchiveMilestoneTypeId, string> = {
  FIRST_REFLECTION: "First moment recorded",
  FIRST_BELIEF: "First belief formed",
  FIRST_BELIEF_CHANGE: "First belief change",
  FIRST_CONTRADICTION: "First contradicting evidence",
  FIRST_CROSS_LIFE_PATTERN: "First cross-life pattern",
  FIRST_STRONG_BELIEF: "First strong belief",
  ARCHIVE_CHANGED_ITS_MIND: "Archive changed its mind",
  TEN_REFLECTIONS: "Ten moments on record",
  FIFTY_REFLECTIONS: "Fifty moments on record",
  ONE_HUNDRED_REFLECTIONS: "One hundred moments on record",
  THIRTY_DAYS_OF_HISTORY: "Thirty days of history",
  NINETY_DAYS_OF_HISTORY: "Ninety days of history",
  FIRST_SURVIVED_CHALLENGE: "First survived challenge",
  FIRST_REPUTATION_STRONG: "Archive trust strengthened",
  FIRST_RECURRING_PATTERN: "First recurring pattern",
  FIRST_ARCHIVE_QUESTION_ANSWERED: "First archive question answered",
};

export const MILESTONE_EXPLANATIONS: Record<ArchiveMilestoneTypeId, string> = {
  FIRST_REFLECTION:
    "The archive began collecting the raw material it needs to track patterns over time.",
  FIRST_BELIEF:
    "The archive moved from collecting moments to identifying a recurring pattern.",
  FIRST_BELIEF_CHANGE:
    "The archive recorded its first shift as new moments changed a working belief.",
  FIRST_CONTRADICTION:
    "The archive stored evidence that did not fit its current belief.",
  FIRST_CROSS_LIFE_PATTERN:
    "The archive found evidence across multiple parts of life.",
  FIRST_STRONG_BELIEF:
    "The archive gained enough aligned evidence to hold this belief with higher confidence.",
  ARCHIVE_CHANGED_ITS_MIND:
    "The archive updated its understanding based on new evidence.",
  TEN_REFLECTIONS:
    "The archive has enough history to compare moments across weeks.",
  FIFTY_REFLECTIONS:
    "The archive now spans a substantial body of your spoken history.",
  ONE_HUNDRED_REFLECTIONS:
    "The archive has a deep longitudinal record to weigh beliefs against.",
  THIRTY_DAYS_OF_HISTORY:
    "The archive has been building for a month of real time.",
  NINETY_DAYS_OF_HISTORY:
    "The archive has a quarter-year span to show how beliefs evolve.",
  FIRST_SURVIVED_CHALLENGE:
    "A belief remained on record after contradicting evidence appeared.",
  FIRST_REPUTATION_STRONG:
    "The archive accumulated enough supporting evidence to rate this belief as well-grounded.",
  FIRST_RECURRING_PATTERN:
    "The archive detected language or themes that keep returning in your moments.",
  FIRST_ARCHIVE_QUESTION_ANSWERED:
    "You asked the archive a structured question and it answered from your evidence.",
};
