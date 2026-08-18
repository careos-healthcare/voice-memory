export type RecurrenceDensitySignalId =
  | "first_reflection_no_second"
  | "repeated_topic_emerging"
  | "unresolved_concern_once"
  | "person_topic_once"
  | "low_recurrence_density"
  | "no_magic_candidate_yet";

export type RecurrenceDensityPromptId =
  | "record_again_when_shows"
  | "say_in_own_words"
  | "worth_recording_later"
  | "same_words_if_fit"
  | "pattern_clearer_when_repeat";

export type RecurrenceDensityEventName =
  | "recurrence_density_signal_detected"
  | "recurrence_density_prompt_shown"
  | "recurrence_density_prompt_dismissed"
  | "recurrence_density_prompt_engaged"
  | "recurrence_density_onboarding_complete";

export interface RecurrenceDensitySignal {
  id: RecurrenceDensitySignalId;
  priority: number;
  label: string;
  evidence: string;
  entryId?: string;
  topicLabel?: string;
}

export interface RecurrenceDensityPromptOffer {
  id: RecurrenceDensityPromptId;
  text: string;
  signalId: RecurrenceDensitySignalId;
  evidence: string;
  entryId?: string;
  topicLabel?: string;
}

export interface RecurrenceDensityState {
  lastShownDay: string | null;
  dismissedCount: number;
  shownThisWeek: number;
  lastPromptId: RecurrenceDensityPromptId | null;
  lastSignalId: RecurrenceDensitySignalId | null;
}

export interface RecurrenceDensityMetrics {
  densityScore: number;
  entryCount: number;
  recurringThemeCount: number;
  repeatedPhraseCount: number;
  singleMentionEntityCount: number;
  hasMagicCandidate: boolean;
  suppressed: boolean;
  suppressionReason: string | null;
}

export interface RecurrenceDensityDebugReport {
  generatedAt: string;
  hasData: boolean;
  withinFirstWeek: boolean;
  dayIndex: number | null;
  state: RecurrenceDensityState;
  metrics: RecurrenceDensityMetrics;
  signals: RecurrenceDensitySignal[];
  previewOffer: RecurrenceDensityPromptOffer | null;
  recentEvents: Array<{ name: string; at: string; meta?: Record<string, string> }>;
}
