import type { MemoryNote } from "@/types/memory-note";

export type FollowupSource =
  | "resurfacing"
  | "then_vs_now"
  | "continuity"
  | "continuation"
  | "revisit_contrast"
  | "partial_return"
  | "unfinished"
  | "recovery"
  | "revisitation"
  | "familiarity_resurfacing";

export interface FollowupPrompt {
  id: string;
  text: string;
  source: FollowupSource;
  noteId: string;
  noteText: string;
  strength: number;
}

export interface FollowupCandidate {
  note: MemoryNote;
  source: FollowupSource;
  priority: number;
}
