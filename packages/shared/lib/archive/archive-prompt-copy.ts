import type { ArchivePostSaveFollowUpId } from "@/types/archive-prompt";

/** First session — no archive belief yet. */
export const FIRST_SESSION_PROMPTS = [
  "What happened today that stuck with you?",
  "What annoyed you today?",
  "Did anything surprise you today?",
  "What are you thinking about right now?",
  "Anything taking up mental space?",
] as const;

export const ARCHIVE_PROMPT_SUPPORT = (belief?: string): string =>
  belief
    ? `Did anything happen recently that supports this belief?`
    : "Did anything happen recently that supports what you have been saying?";

export const ARCHIVE_PROMPT_CHALLENGE = (belief?: string): string =>
  belief
    ? `Did anything happen recently that challenges this belief?`
    : "Did anything happen recently that challenges what you have been saying?";

export const ARCHIVE_PROMPT_GENERAL = "What is taking up mental space today?";

export function archivePromptRecentChange(strengthening: boolean): string {
  return strengthening
    ? "This belief became stronger recently. Have you noticed that too?"
    : "Something shifted in the archive recently. Does that match what you have noticed?";
}

export function archivePromptMissingArea(area: string): string {
  const label = area.toLowerCase();
  return `The archive has not heard much about ${label} lately. What has been happening there?`;
}

export const ARCHIVE_PROMPT_OPEN_UNCERTAIN =
  "The archive is still uncertain here. What else should it know?";

export const POST_SAVE_FOLLOW_UP_COPY: Record<ArchivePostSaveFollowUpId, string> = {
  anything_else: "Anything else related to that?",
  support_or_challenge: "Did this support or challenge the belief?",
  more_context: "Would you like to add more context?",
};
