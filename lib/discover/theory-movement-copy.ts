import { ARCHIVE_EMOTIONAL } from "@/lib/archive/archive-emotional-copy";

export const THEORY_MOVEMENT_COPY = {
  feedTitle: "Belief movement",
  feedLead: "How your archive shifted since your last visit — no reminders, just what changed.",
  confidenceIncreased: ARCHIVE_EMOTIONAL.confidenceIncreased,
  confidenceDecreased: ARCHIVE_EMOTIONAL.theoryWeakened,
  theoryRetired: ARCHIVE_EMOTIONAL.theoryRetired,
  whyLabel: "Why",
  supportingWhy: "New evidence appeared in recent moments.",
  supportingWhyArea: (area: string) => `New evidence appeared in ${area}.`,
  contradictingWhy: "Recent moments contradict this theory.",
  retiredWhy: "Recent evidence no longer supports it.",
  emptyTitle: "No movement yet",
  emptyBody:
    "After your next visit, confidence shifts and retired theories will show here.",
} as const;
