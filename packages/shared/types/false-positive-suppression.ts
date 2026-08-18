import type { RewriteCandidateFlag } from "@/types/callback-quality-review";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export type FalsePositiveReason =
  | "weak_emotional_contrast"
  | "topic_recurrence_only"
  | "could_apply_to_many"
  | "shown_recently"
  | "quotes_not_different"
  | "single_weak_signal"
  | "ignored_similar_before"
  | "overclaims_change"
  | "generated_interpretation"
  | "suppressed_pattern"
  | "weak_hierarchy";

export type FalsePositiveSourceModule =
  | "knows_me"
  | "resurfacing"
  | "revisit_reward"
  | "follow_up"
  | "archive_gravity"
  | "milestone"
  | "chaptering"
  | "voice_identity"
  | "living_resurfacing"
  | "delayed_payoff"
  | "memory_notes"
  | "unknown";

export interface FalsePositiveVerdict {
  suppressed: boolean;
  reasons: FalsePositiveReason[];
  missingEvidence: string[];
  rewriteFlags: RewriteCandidateFlag[];
  hierarchyScore?: number;
}

export interface FalsePositiveAssessmentInput {
  note: MemoryNote;
  entries?: JournalEntry[];
  sourceModule?: FalsePositiveSourceModule;
}
