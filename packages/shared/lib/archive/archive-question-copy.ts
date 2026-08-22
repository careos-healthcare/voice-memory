import type { ArchiveQuestionButton, ArchiveQuestionId } from "@/types/archive-question";

export const QUESTION_THE_ARCHIVE_HEADLINE = "Question the Archive";

export const QUESTION_THE_ARCHIVE_LEAD =
  "Ask the archive about its current belief — structured answers from your evidence, not a conversation.";

export const ARCHIVE_QUESTION_BUTTONS: readonly ArchiveQuestionButton[] = [
  { id: "WHY", label: "Why?", answerKey: "WHY" },
  { id: "SHOW_EVIDENCE", label: "Show evidence", answerKey: "SUPPORTING_EVIDENCE" },
  {
    id: "SHOW_CONTRADICTIONS",
    label: "Show contradictions",
    answerKey: "CONTRADICTING_EVIDENCE",
  },
  {
    id: "WHEN_DID_THIS_START",
    label: "When did this start?",
    answerKey: "FIRST_APPEARED",
  },
  {
    id: "IS_IT_GETTING_STRONGER",
    label: "Is it getting stronger?",
    answerKey: "STRENGTH_DIRECTION",
  },
  {
    id: "WHAT_WOULD_CHANGE_IT",
    label: "What would change its mind?",
    answerKey: "WHAT_CHANGES_THIS",
  },
  {
    id: "WHAT_CHANGED_RECENTLY",
    label: "What changed recently?",
    answerKey: "RECENT_CHANGES",
  },
  {
    id: "HOW_RELIABLE_IS_IT",
    label: "How reliable is it?",
    answerKey: "RELIABILITY",
  },
  {
    id: "WHERE_DOES_THIS_APPEAR",
    label: "Where does this appear?",
    answerKey: "LIFE_AREAS",
  },
  {
    id: "STRONGEST_EVIDENCE",
    label: "Strongest evidence",
    answerKey: "STRONGEST_EVIDENCE",
  },
  {
    id: "WHY_SHOULD_I_CARE",
    label: "Why should I care?",
    answerKey: "IMPLICATIONS",
  },
] as const;

export const ARCHIVE_QUESTION_PROMPTS: Record<ArchiveQuestionId, string> = {
  WHY: "Why does the archive believe this?",
  SHOW_EVIDENCE: "What evidence supports this belief?",
  SHOW_CONTRADICTIONS: "What contradicts this belief?",
  WHEN_DID_THIS_START: "When did this belief first appear?",
  IS_IT_GETTING_STRONGER: "Is this belief getting stronger or weaker?",
  WHAT_WOULD_CHANGE_IT: "What would change the archive's mind?",
  WHAT_CHANGED_RECENTLY: "What changed recently?",
  HOW_RELIABLE_IS_IT: "How reliable is this belief?",
  WHERE_DOES_THIS_APPEAR: "Where does this belief appear in your life?",
  STRONGEST_EVIDENCE: "What is the strongest evidence?",
  WHY_SHOULD_I_CARE: "Why should I care about this belief?",
};

/** User-facing trust band — no reputation subsystem labels. */
export const ARCHIVE_TRUST_BAND_LABEL = {
  low: "Low",
  developing: "Developing",
  strong: "Strong",
} as const;
