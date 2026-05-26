import { todayKey } from "@/lib/dates";
import { buildEntityMemoryFromEntries } from "@/lib/entity-memory";
import { trackLocalEvent, readLocalEvents } from "@/lib/local-analytics";
import { getTopPhrases } from "@/lib/patterns/phrase-memory";
import {
  buildFirstWeekTimingRecommendations,
  firstWeekDayIndex,
  isWithinFirstWeek,
  readFirstWeekPromptState,
} from "@/lib/retention/first-week";
import { hasFunnelStage, FIRST_WEEK_FUNNEL_EVENTS } from "@/lib/retention/first-week-funnel";
import { getSilenceIntelligenceEffects } from "@/lib/restraint/silence-intelligence";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  RecurrenceDensityEventName,
  RecurrenceDensityMetrics,
  RecurrenceDensityPromptId,
  RecurrenceDensityPromptOffer,
  RecurrenceDensitySignal,
  RecurrenceDensitySignalId,
  RecurrenceDensityState,
} from "@/types/recurrence-density";

export const RECURRENCE_DENSITY_EVENTS = {
  signalDetected: "recurrence_density_signal_detected",
  promptShown: "recurrence_density_prompt_shown",
  promptDismissed: "recurrence_density_prompt_dismissed",
  promptEngaged: "recurrence_density_prompt_engaged",
  onboardingComplete: "recurrence_density_onboarding_complete",
} as const satisfies Record<string, RecurrenceDensityEventName>;

const STATE_KEY = "voicememory_recurrence_density_state";
const MAGIC_CONFIRMED_KEY = "voicememory_first_magic_confirmed";
const MAX_DISMISSALS = 3;
const LOW_DENSITY_THRESHOLD = 0.32;
const MIN_ENTRIES_FOR_MAGIC_WAIT = 3;

const PROMPT_COPY: Record<RecurrenceDensityPromptId, string> = {
  record_again_when_shows: "Record again about this when it shows up.",
  say_in_own_words: "If this comes back, say it in your own words.",
  worth_recording_later: "This may be worth recording again later.",
  same_words_if_fit: "Use the same words if they still fit.",
  pattern_clearer_when_repeat: "The pattern gets clearer when your own words repeat.",
};

const SIGNAL_TO_PROMPT: Record<RecurrenceDensitySignalId, RecurrenceDensityPromptId> = {
  first_reflection_no_second: "worth_recording_later",
  repeated_topic_emerging: "pattern_clearer_when_repeat",
  unresolved_concern_once: "say_in_own_words",
  person_topic_once: "record_again_when_shows",
  low_recurrence_density: "same_words_if_fit",
  no_magic_candidate_yet: "pattern_clearer_when_repeat",
};

const BLOCKED_TERMS = [
  "streak",
  "daily habit",
  "don't miss",
  "hurry",
  "urgent",
  "productivity",
  "goal",
  "fomo",
  "coaching",
  "therapy",
  "mindfulness",
  "self-awareness",
  "you should",
  "try to",
];

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function defaultState(): RecurrenceDensityState {
  return {
    lastShownDay: null,
    dismissedCount: 0,
    shownThisWeek: 0,
    lastPromptId: null,
    lastSignalId: null,
  };
}

export function readRecurrenceDensityState(): RecurrenceDensityState {
  if (!isBrowser()) return defaultState();
  try {
    const raw = localStorage.getItem(STATE_KEY);
    if (!raw) return defaultState();
    return { ...defaultState(), ...(JSON.parse(raw) as RecurrenceDensityState) };
  } catch {
    return defaultState();
  }
}

function writeRecurrenceDensityState(state: RecurrenceDensityState): void {
  if (!isBrowser()) return;
  localStorage.setItem(STATE_KEY, JSON.stringify(state));
}

function trackDensityEvent(name: RecurrenceDensityEventName, meta?: Record<string, string>): void {
  trackLocalEvent(name, meta);
}

export function isRecurrenceDensityCopyAllowed(text: string): boolean {
  const lower = text.toLowerCase();
  return !BLOCKED_TERMS.some((term) => lower.includes(term));
}

function hasMagicCandidateYet(): boolean {
  if (!isBrowser()) return false;
  if (hasFunnelStage(FIRST_WEEK_FUNNEL_EVENTS.firstResurfacingCandidate)) return true;
  if (hasFunnelStage(FIRST_WEEK_FUNNEL_EVENTS.firstMagicMoment)) return true;
  try {
    if (localStorage.getItem(MAGIC_CONFIRMED_KEY)) return true;
  } catch {
    // ignore
  }
  const events = readLocalEvents();
  return events.some(
    (event) =>
      event.name === "magic_candidate_created" ||
      event.name === FIRST_WEEK_FUNNEL_EVENTS.firstResurfacingCandidate,
  );
}

function latestEntry(entries: JournalEntry[]): JournalEntry | null {
  if (entries.length === 0) return null;
  return [...entries].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  )[0];
}

function concernText(entry: JournalEntry): string | null {
  const concern =
    entry.reflection.hiddenConcern?.trim() ||
    entry.reflection.avoidedOrVagueArea?.trim() ||
    "";
  return concern || null;
}

function entriesSharingTheme(entries: JournalEntry[], theme: string): number {
  const key = theme.toLowerCase();
  return entries.filter((entry) =>
    entry.reflection.recurringThemes.some((t) => t.toLowerCase() === key),
  ).length;
}

export function computeRecurrenceDensityScore(entries: JournalEntry[]): number {
  if (entries.length === 0) return 0;

  const recurringThemes = new Set<string>();
  for (const entry of entries) {
    for (const theme of entry.reflection.recurringThemes) {
      if (entriesSharingTheme(entries, theme) >= 2) {
        recurringThemes.add(theme.toLowerCase());
      }
    }
  }

  const phrases = getTopPhrases(entries, 20);
  const repeatedPhraseCount = phrases.filter((phrase) => phrase.entryIds.length >= 2).length;

  const entities = buildEntityMemoryFromEntries(entries);
  const repeatedEntities = [
    ...entities.people,
    ...entities.topics,
    ...entities.concerns,
  ].filter((entity) => entity.mentionCount >= 2).length;

  const signals =
    recurringThemes.size + repeatedPhraseCount + repeatedEntities;
  const capacity = Math.max(2, entries.length * 2);
  return Math.min(1, signals / capacity);
}

export function analyzeRecurrenceDensitySignals(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): RecurrenceDensitySignal[] {
  const signals: RecurrenceDensitySignal[] = [];
  const count = entries.length;
  const latest = latestEntry(entries);

  if (count === 1 && latest) {
    signals.push({
      id: "first_reflection_no_second",
      priority: 88,
      label: "First reflection, no second yet",
      evidence: "One reflection saved — a second note helps repeated language emerge.",
      entryId: latest.id,
    });
  }

  if (latest && count >= 2) {
    for (const theme of latest.reflection.recurringThemes) {
      const shared = entriesSharingTheme(entries, theme);
      if (shared >= 2) {
        signals.push({
          id: "repeated_topic_emerging",
          priority: 84,
          label: "Repeated topic emerging",
          evidence: `"${theme}" appears across ${shared} reflections.`,
          entryId: latest.id,
          topicLabel: theme,
        });
        break;
      }
    }

    const repeatedSignal = latest.reflection.repeatedSignal?.trim();
    if (repeatedSignal && !repeatedSignal.toLowerCase().startsWith("no clear repeat")) {
      signals.push({
        id: "repeated_topic_emerging",
        priority: 80,
        label: "Repeated language in latest reflection",
        evidence: repeatedSignal.slice(0, 120),
        entryId: latest.id,
      });
    }
  }

  if (latest) {
    const concern = concernText(latest);
    if (concern) {
      const concernKey = concern.toLowerCase().slice(0, 40);
      const others = entries.filter(
        (entry) =>
          entry.id !== latest.id &&
          concernText(entry)?.toLowerCase().includes(concernKey.slice(0, 20)),
      );
      if (others.length === 0) {
        signals.push({
          id: "unresolved_concern_once",
          priority: 78,
          label: "Concern mentioned once",
          evidence: concern.slice(0, 120),
          entryId: latest.id,
        });
      }
    }
  }

  if (latest) {
    const snapshot = buildEntityMemoryFromEntries(entries);
    const singles = [...snapshot.people, ...snapshot.topics].filter(
      (entity) =>
        entity.mentionCount === 1 && entity.entryIds.includes(latest.id),
    );
    if (singles.length > 0) {
      const entity = singles[0];
      signals.push({
        id: "person_topic_once",
        priority: 76,
        label: "Person or topic appears once",
        evidence: `"${entity.name}" showed up in one reflection so far.`,
        entryId: latest.id,
        topicLabel: entity.name,
      });
    }
  }

  const densityScore = computeRecurrenceDensityScore(entries);
  if (count >= 2 && densityScore < LOW_DENSITY_THRESHOLD) {
    signals.push({
      id: "low_recurrence_density",
      priority: 72,
      label: "Low recurrence density",
      evidence: `Density ${Math.round(densityScore * 100)}% — few repeated words or themes yet.`,
    });
  }

  if (count >= MIN_ENTRIES_FOR_MAGIC_WAIT && !hasMagicCandidateYet()) {
    signals.push({
      id: "no_magic_candidate_yet",
      priority: 70,
      label: "No magic candidate yet",
      evidence: `${count} reflections — not enough repeated language for a strong callback yet.`,
    });
  }

  const deduped = new Map<RecurrenceDensitySignalId, RecurrenceDensitySignal>();
  for (const signal of signals.sort((a, b) => b.priority - a.priority)) {
    if (!deduped.has(signal.id)) deduped.set(signal.id, signal);
  }

  return [...deduped.values()].sort((a, b) => b.priority - a.priority);
}

export function computeRecurrenceDensityMetrics(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): RecurrenceDensityMetrics {
  const signals = analyzeRecurrenceDensitySignals(entries);
  const recurringThemeCount = new Set(
    entries.flatMap((entry) =>
      entry.reflection.recurringThemes.filter(
        (theme) => entriesSharingTheme(entries, theme) >= 2,
      ),
    ),
  ).size;
  const repeatedPhraseCount = getTopPhrases(entries, 20).filter(
    (phrase) => phrase.entryIds.length >= 2,
  ).length;
  const snapshot = buildEntityMemoryFromEntries(entries);
  const singleMentionEntityCount = [...snapshot.people, ...snapshot.topics].filter(
    (entity) => entity.mentionCount === 1,
  ).length;

  const suppression = resolveRecurrenceDensitySuppression(entries);

  return {
    densityScore: computeRecurrenceDensityScore(entries),
    entryCount: entries.length,
    recurringThemeCount,
    repeatedPhraseCount,
    singleMentionEntityCount,
    hasMagicCandidate: hasMagicCandidateYet(),
    suppressed: suppression.suppressed,
    suppressionReason: suppression.reason,
  };
}

function resolveRecurrenceDensitySuppression(
  entries: JournalEntry[],
): { suppressed: boolean; reason: string | null } {
  if (!isWithinFirstWeek(entries)) {
    return { suppressed: true, reason: "Outside first week" };
  }

  const state = readRecurrenceDensityState();
  if (state.lastShownDay === todayKey()) {
    return { suppressed: true, reason: "Already shown today" };
  }
  if (state.dismissedCount >= MAX_DISMISSALS) {
    return { suppressed: true, reason: "Dismissed too many times" };
  }

  const gentleState = readFirstWeekPromptState();
  if (gentleState.lastShownDay === todayKey()) {
    return { suppressed: true, reason: "Gentle return prompt shown today" };
  }

  const silence = getSilenceIntelligenceEffects(entries);
  if (silence.suppressMemoryNotes || silence.essentialsOnly) {
    return { suppressed: true, reason: "Quiet mode active" };
  }

  const timing = buildFirstWeekTimingRecommendations(entries);
  if (timing[0]?.action === "stay_silent" && timing[0].priority >= 70) {
    return { suppressed: true, reason: timing[0].reason };
  }

  if (analyzeRecurrenceDensitySignals(entries).length === 0) {
    return { suppressed: true, reason: "No qualifying signals" };
  }

  return { suppressed: false, reason: null };
}

function buildOffer(
  entries: JournalEntry[],
  options: { recordShown: boolean },
): RecurrenceDensityPromptOffer | null {
  const suppression = resolveRecurrenceDensitySuppression(entries);
  if (suppression.suppressed) return null;

  const signals = analyzeRecurrenceDensitySignals(entries);
  const top = signals[0];
  if (!top) return null;

  const promptId = SIGNAL_TO_PROMPT[top.id];
  const text = PROMPT_COPY[promptId];
  if (!isRecurrenceDensityCopyAllowed(text)) return null;

  if (options.recordShown) {
    recordRecurrenceDensityShown(promptId, top.id);
    trackDensityEvent(RECURRENCE_DENSITY_EVENTS.promptShown, {
      promptId,
      signalId: top.id,
      entryId: top.entryId ?? "",
      topicLabel: top.topicLabel ?? "",
      funnel: "first_week",
    });
  } else {
    trackDensityEvent(RECURRENCE_DENSITY_EVENTS.signalDetected, {
      signalId: top.id,
      entryId: top.entryId ?? "",
    });
  }

  return {
    id: promptId,
    text,
    signalId: top.id,
    evidence: top.evidence,
    entryId: top.entryId,
    topicLabel: top.topicLabel,
  };
}

export function recordRecurrenceDensityShown(
  promptId: RecurrenceDensityPromptId,
  signalId: RecurrenceDensitySignalId,
): void {
  const state = readRecurrenceDensityState();
  writeRecurrenceDensityState({
    lastShownDay: todayKey(),
    dismissedCount: state.dismissedCount,
    shownThisWeek: state.shownThisWeek + 1,
    lastPromptId: promptId,
    lastSignalId: signalId,
  });
}

export function recordRecurrenceDensityDismissed(): void {
  const state = readRecurrenceDensityState();
  writeRecurrenceDensityState({
    ...state,
    dismissedCount: state.dismissedCount + 1,
  });
  trackDensityEvent(RECURRENCE_DENSITY_EVENTS.promptDismissed, {
    promptId: state.lastPromptId ?? "",
    signalId: state.lastSignalId ?? "",
  });
}

export function recordRecurrenceDensityEngaged(): void {
  const state = readRecurrenceDensityState();
  writeRecurrenceDensityState({
    ...state,
    dismissedCount: 0,
  });
  trackDensityEvent(RECURRENCE_DENSITY_EVENTS.promptEngaged, {
    promptId: state.lastPromptId ?? "",
    signalId: state.lastSignalId ?? "",
  });
}

/** At most one recurrence-density prompt per calendar day during week one. */
export function pickRecurrenceDensityPrompt(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): RecurrenceDensityPromptOffer | null {
  return buildOffer(entries, { recordShown: true });
}

export function previewRecurrenceDensityPrompt(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): RecurrenceDensityPromptOffer | null {
  return buildOffer(entries, { recordShown: false });
}

export function observeRecurrenceDensityOnboardingComplete(): void {
  trackDensityEvent(RECURRENCE_DENSITY_EVENTS.onboardingComplete);
}

export function listRecurrenceDensityEvents(limit = 24): Array<{
  name: string;
  at: string;
  meta?: Record<string, string>;
}> {
  const names = new Set<string>(Object.values(RECURRENCE_DENSITY_EVENTS));
  return readLocalEvents()
    .filter((event) => names.has(event.name))
    .slice(-limit)
    .map((event) => ({ name: event.name, at: event.at, meta: event.meta }));
}

export { PROMPT_COPY as RECURRENCE_DENSITY_PROMPT_COPY };
