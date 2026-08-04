import type { BeliefRecallLevelId } from "@/types/belief-recall";

export const BELIEF_RECALL_QUESTION = "Do you remember this belief?";

export const BELIEF_RECALL_NOTE_QUESTION = "What stuck with you?";

export const BELIEF_RECALL_DISMISS = "Not today";

export const BELIEF_RECALL_LEVEL_LABELS: Record<BeliefRecallLevelId, string> = {
  yes_clearly: "Yes, clearly",
  vaguely: "Vaguely",
  no: "No",
};

export const BELIEF_RECALL_DELAY_MS = 7 * 24 * 60 * 60 * 1000;
export const BELIEF_RECALL_COOLDOWN_MS = 14 * 24 * 60 * 60 * 1000;

export const BELIEF_RECALL_STRONG_REMEMBERED_PERCENT = 50;
export const BELIEF_RECALL_WEAK_REMEMBERED_PERCENT = 25;
