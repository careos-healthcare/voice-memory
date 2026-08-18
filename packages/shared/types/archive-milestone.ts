/** Archive Milestones v1 — archive history moments, not gamification. */

export const ARCHIVE_MILESTONE_TYPE_IDS = [
  "FIRST_REFLECTION",
  "FIRST_BELIEF",
  "FIRST_BELIEF_CHANGE",
  "FIRST_CONTRADICTION",
  "FIRST_CROSS_LIFE_PATTERN",
  "FIRST_STRONG_BELIEF",
  "ARCHIVE_CHANGED_ITS_MIND",
  "TEN_REFLECTIONS",
  "FIFTY_REFLECTIONS",
  "ONE_HUNDRED_REFLECTIONS",
  "THIRTY_DAYS_OF_HISTORY",
  "NINETY_DAYS_OF_HISTORY",
  "FIRST_SURVIVED_CHALLENGE",
  "FIRST_REPUTATION_STRONG",
  "FIRST_RECURRING_PATTERN",
  "FIRST_ARCHIVE_QUESTION_ANSWERED",
] as const;

export type ArchiveMilestoneTypeId = (typeof ARCHIVE_MILESTONE_TYPE_IDS)[number];

export interface ArchiveMilestone {
  id: string;
  type: ArchiveMilestoneTypeId;
  /** Short label — archive voice. */
  title: string;
  /** Why this matters — archive evolution, not user reward. */
  explanation: string;
  occurredAt: string;
  periodLabel: string;
}

export interface ArchiveMilestonesView {
  milestones: ArchiveMilestone[];
  latest: ArchiveMilestone | null;
}
