/** Plain revisit reward lines — no refinement imports (avoids copy module cycles). */

export const REVISIT_REWARD_COPY = {
  soundDifferentNow: "You sound different now.",
  notNamedYet: "You had not named this yet.",
  usedToTakeSpace: "This used to take up more room.",
  beforeThingsChanged: "You were carrying this differently then.",
  soundFurtherAway: "You sound further away from this now.",
} as const;

export type RevisitRewardCopyLine =
  (typeof REVISIT_REWARD_COPY)[keyof typeof REVISIT_REWARD_COPY];

export const TOPIC_RECURRENCE_TEXT =
  /\b(appeared again|money returned|work appeared|topic appeared|similar theme|came back to the same place|came back to the same loop|showed up again|keeps showing up)\b/i;

export function isTopicRecurrenceCopy(text: string): boolean {
  return TOPIC_RECURRENCE_TEXT.test(text);
}
