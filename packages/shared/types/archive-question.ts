/** Question The Archive v1 — structured interrogation (not chat). */

export type ArchiveQuestionId =
  | "WHY"
  | "SHOW_EVIDENCE"
  | "SHOW_CONTRADICTIONS"
  | "WHEN_DID_THIS_START"
  | "IS_IT_GETTING_STRONGER"
  | "WHAT_WOULD_CHANGE_IT"
  | "WHAT_CHANGED_RECENTLY"
  | "HOW_RELIABLE_IS_IT"
  | "WHERE_DOES_THIS_APPEAR"
  | "STRONGEST_EVIDENCE"
  | "WHY_SHOULD_I_CARE";

export type ArchiveQuestionAnswerKey =
  | "WHY"
  | "SUPPORTING_EVIDENCE"
  | "CONTRADICTING_EVIDENCE"
  | "FIRST_APPEARED"
  | "STRENGTH_DIRECTION"
  | "WHAT_CHANGES_THIS"
  | "RECENT_CHANGES"
  | "RELIABILITY"
  | "LIFE_AREAS"
  | "STRONGEST_EVIDENCE"
  | "IMPLICATIONS";

export type ArchiveQuestionAnswer = {
  questionId: ArchiveQuestionId;
  questionLabel: string;
  /** Archive explanation — no advice or coaching. */
  answerLines: string[];
  /** Supporting or contradicting evidence excerpts (truncated). */
  evidenceLines: string[];
};

export type ArchiveQuestionAnswers = Record<
  ArchiveQuestionAnswerKey,
  ArchiveQuestionAnswer
>;

export type ArchiveQuestionButton = {
  id: ArchiveQuestionId;
  label: string;
  answerKey: ArchiveQuestionAnswerKey;
};
