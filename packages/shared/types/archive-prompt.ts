/** Archive Prompt Engine v1 — conversation starters, not advice. */

export const ARCHIVE_PROMPT_TYPE_IDS = [
  "SUPPORT_PROMPT",
  "CHALLENGE_PROMPT",
  "MISSING_AREA_PROMPT",
  "RECENT_CHANGE_PROMPT",
  "OPEN_QUESTION_PROMPT",
  "GENERAL_CAPTURE_PROMPT",
] as const;

export type ArchivePromptTypeId = (typeof ARCHIVE_PROMPT_TYPE_IDS)[number];

export type ArchivePromptMode = "first_session" | "archive_aware";

export interface ArchivePrompt {
  id: string;
  type: ArchivePromptTypeId;
  text: string;
  priority: number;
}

export interface ArchivePromptSet {
  mode: ArchivePromptMode;
  prompts: ArchivePrompt[];
}

export type ArchivePostSaveFollowUpId =
  | "anything_else"
  | "support_or_challenge"
  | "more_context";

export interface ArchivePostSaveFollowUp {
  id: ArchivePostSaveFollowUpId;
  text: string;
}
