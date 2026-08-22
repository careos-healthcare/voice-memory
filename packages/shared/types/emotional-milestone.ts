export type EmotionalMilestoneKind =
  | "first_calmer_topic"
  | "topic_absent_after_intensity"
  | "phrase_disappeared"
  | "direct_naming"
  | "recovery_after_loop";

export type EmotionalMilestoneContext = "memory" | "timeline" | "monthly" | "entry";

export interface EmotionalMilestone {
  id: string;
  kind: EmotionalMilestoneKind;
  text: string;
  strength: number;
  subject?: string;
  entryId?: string;
  pastEntryId?: string;
  href?: string;
}

export interface EmotionalMilestoneReport {
  milestones: EmotionalMilestone[];
  hasData: boolean;
}

export interface EmotionalMilestoneCopyExample {
  kind: EmotionalMilestoneKind;
  message: string;
  whenShown: string;
}
