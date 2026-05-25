import { countLocalEvents, hasLocalEvent, trackLocalEvent } from "@/lib/local-analytics";

export const FIRST_WEEK_RETENTION_EVENTS = {
  firstRevisitCompleted: "first_revisit_completed",
  firstCallbackLanded: "first_callback_landed",
  earlyArchiveAttachment: "early_archive_attachment",
  returnPromptOpened: "return_prompt_opened",
  reflectionAfterPrompt: "reflection_after_prompt",
  silenceHelpedReturn: "silence_helped_return",
  revisitEmotionalPayoff: "revisit_emotional_payoff",
} as const;

export type FirstWeekRetentionEventName =
  (typeof FIRST_WEEK_RETENTION_EVENTS)[keyof typeof FIRST_WEEK_RETENTION_EVENTS];

const PENDING_PROMPT_KEY = "voicememory_return_prompt_pending";

export function trackFirstWeekEvent(
  name: FirstWeekRetentionEventName,
  meta?: Record<string, string>,
): void {
  trackLocalEvent(name, meta);
}

export function trackFirstRevisitCompleted(entryId: string): void {
  if (hasLocalEvent(FIRST_WEEK_RETENTION_EVENTS.firstRevisitCompleted)) return;
  trackFirstWeekEvent(FIRST_WEEK_RETENTION_EVENTS.firstRevisitCompleted, { entryId });
}

export function trackFirstCallbackLanded(noteId: string): void {
  if (hasLocalEvent(FIRST_WEEK_RETENTION_EVENTS.firstCallbackLanded)) return;
  trackFirstWeekEvent(FIRST_WEEK_RETENTION_EVENTS.firstCallbackLanded, { noteId });
}

export function trackEarlyArchiveAttachment(level: string): void {
  if (hasLocalEvent(FIRST_WEEK_RETENTION_EVENTS.earlyArchiveAttachment)) return;
  trackFirstWeekEvent(FIRST_WEEK_RETENTION_EVENTS.earlyArchiveAttachment, { level });
}

export function trackReturnPromptOpened(promptId: string): void {
  trackFirstWeekEvent(FIRST_WEEK_RETENTION_EVENTS.returnPromptOpened, { promptId });
}

export function markReturnPromptPending(promptId: string): void {
  if (typeof window === "undefined") return;
  sessionStorage.setItem(PENDING_PROMPT_KEY, promptId);
}

export function consumeReturnPromptPending(): string | null {
  if (typeof window === "undefined") return null;
  const id = sessionStorage.getItem(PENDING_PROMPT_KEY);
  sessionStorage.removeItem(PENDING_PROMPT_KEY);
  return id;
}

export function trackReflectionAfterPromptIfPending(): void {
  const promptId = consumeReturnPromptPending();
  if (!promptId) return;
  trackFirstWeekEvent(FIRST_WEEK_RETENTION_EVENTS.reflectionAfterPrompt, { promptId });
}

export function trackSilenceHelpedReturn(): void {
  trackFirstWeekEvent(FIRST_WEEK_RETENTION_EVENTS.silenceHelpedReturn);
}

export function trackRevisitEmotionalPayoff(entryId: string, noteId: string): void {
  trackFirstWeekEvent(FIRST_WEEK_RETENTION_EVENTS.revisitEmotionalPayoff, {
    entryId,
    noteId,
  });
}

export function countFirstWeekEvents(): Record<string, number> {
  const names = Object.values(FIRST_WEEK_RETENTION_EVENTS);
  return Object.fromEntries(names.map((name) => [name, countLocalEvents(name)]));
}
