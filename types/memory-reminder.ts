export type MemoryReminderKind =
  | "old_reflection_revisit"
  | "topic_absent"
  | "resurfaced_loop"
  | "calmer_return";

export type MemoryReminderContext = "homepage" | "reminders";

export interface MemoryReminder {
  id: string;
  text: string;
  kind: MemoryReminderKind;
  strength: number;
  pastQuote?: string;
  currentQuote?: string;
  pastEntryId?: string;
  entryId?: string;
  pastDateLabel?: string;
  currentDateLabel?: string;
  href: string;
}

export interface MemoryReminderReport {
  reminders: MemoryReminder[];
  hasData: boolean;
}

export interface MemoryReminderCopyExample {
  kind: MemoryReminderKind;
  message: string;
  whenShown: string;
}
