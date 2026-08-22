import type { FounderTestChecklistItem } from "@/types/founder-test";

export const FOUNDER_TEST_CHECKLIST_ITEM_IDS = [
  "first_reflection",
  "three_reflections",
  "five_reflections",
  "opened_blind_spots",
  "opened_discover",
  "blind_spot_reaction",
  "chatgpt_difference",
  "return_reason",
  "returned_7_days",
  "would_pay",
] as const;

export type FounderTestChecklistItemId = (typeof FOUNDER_TEST_CHECKLIST_ITEM_IDS)[number];

export const FOUNDER_TEST_CHECKLIST_LABELS: Record<FounderTestChecklistItemId, string> = {
  first_reflection: "User records first reflection",
  three_reflections: "User reaches 3 reflections",
  five_reflections: "User reaches 5 reflections",
  opened_blind_spots: "User opens Blind Spots",
  opened_discover: "User opens Discover",
  blind_spot_reaction: "User reacts to first blind spot",
  chatgpt_difference: "User explains difference from ChatGPT",
  return_reason: "User says what would make them return",
  returned_7_days: "User returns within 7 days",
  would_pay: "User says whether they would pay",
};

export const FOUNDER_TEST_INTERVIEW_QUESTIONS = [
  "What was happening right before you opened ArchiveMe?",
  "What were you hoping it would help you do?",
  "What did you get that you could not get from Notes or ChatGPT?",
  "What would make you open it tomorrow?",
  "If I deleted it today, what would you miss?",
  "Did any insight feel surprising, uncomfortable, or obvious?",
  "Would you pay for this? Why or why not?",
] as const;

/** Evolving-understanding validation — run after first working theory (see founder-evolving-validation.ts). */
export const FOUNDER_EVOLVING_INTERVIEW_QUESTIONS = [
  "Which felt more accurate — “blind spot” or “working theory”? (Blind spot / Working theory / No difference)",
  "When you opened Discover, what were you expecting to see?",
  "Before opening ArchiveMe today, were you curious whether it had changed its view of you? (Yes / Maybe / No)",
  "Did you come back on your own, days later, to see whether your archive’s view had changed?",
] as const;

export const FOUNDER_TEST_CORE_QUESTION =
  "ChatGPT answers today. ArchiveMe shows what keeps repeating across your life.";

export function buildDefaultFounderTestChecklist(): FounderTestChecklistItem[] {
  return FOUNDER_TEST_CHECKLIST_ITEM_IDS.map((id) => ({
    id,
    label: FOUNDER_TEST_CHECKLIST_LABELS[id],
    completed: false,
  }));
}

export function isFounderTestChecklistItemId(id: string): id is FounderTestChecklistItemId {
  return (FOUNDER_TEST_CHECKLIST_ITEM_IDS as readonly string[]).includes(id);
}
