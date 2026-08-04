import type { PersonalTheoryStatus } from "@/types/personal-theory";

import {
  BELIEF_DOMINANCE_ARCHIVE_TRUST,
  BELIEF_DOMINANCE_EVIDENCE_FOR_BELIEF,
} from "@/lib/product/belief-dominance-copy";

export const ARCHIVE_BELIEF_HEADLINE = "What your archive currently believes";

export const ARCHIVE_BELIEF_PREFIX = "Your archive currently believes:";

export const ARCHIVE_BELIEF_WHAT_CHANGED_TITLE = "What changed";

export const ARCHIVE_BELIEF_EVIDENCE_TITLE = "Why the archive currently weighs this";

export const ARCHIVE_BELIEF_EVIDENCE_LABELS = {
  supporting: "Supporting moments",
  contradictions: "Contradictions",
  lifeAreas: "Life areas",
  costEvidence: "Cost evidence",
  predictionFailures: "Prediction failures",
} as const;

export const ARCHIVE_BELIEF_EMPTY = "Record another moment.";

export const HOME_ARCHIVE_BELIEF_LEAD = "Your archive is building a view of you.";

export const HOME_ARCHIVE_BELIEF_BULLETS = [
  "strengthen a belief",
  "weaken a belief",
  "contradict a belief",
  "create a new belief",
] as const;

export const MEMORY_CURRENT_BELIEF_TITLE = "Current archive belief";

export const ARCHIVE_BELIEF_STATUS_LABEL: Record<PersonalTheoryStatus, string> = {
  under_review: "Under review",
  strengthening: "Strengthening",
  weakening: "Weakening",
  resolved: "Resolved",
  disproven: "Disproven",
};

export const ARCHIVE_BELIEF_STATUS_EXPLANATION: Record<PersonalTheoryStatus, string> = {
  under_review: "Your archive is still evaluating this against prior moments.",
  strengthening: "Recent moments support this theory.",
  weakening: "Recent moments may be pulling against this theory.",
  resolved: "Your archive may no longer treat this as an active working case.",
  disproven: "Later evidence may no longer support keeping this belief active.",
};

export const THEORIES_PAGE_ARCHIVE_BELIEFS = {
  eyebrow: BELIEF_DOMINANCE_ARCHIVE_TRUST,
  title: "Beliefs the archive holds",
  lead: "What your archive currently believes — each item is a working case file, not a fixed label.",
} as const;

export { BELIEF_DOMINANCE_EVIDENCE_FOR_BELIEF };
