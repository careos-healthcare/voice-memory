import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { isListeningModeEnabled } from "@/lib/listening-mode";
import { readLocalEvents } from "@/lib/local-analytics";
import { buildSilenceTimingDebugSnapshot } from "@/lib/refinement/silence-calibration";
import { detectRevisitFatigue } from "@/lib/refinement/revisit-sequencing";
import { buildSacrednessReport } from "@/lib/restraint/sacredness";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  SilenceIntelligenceDebugReport,
  SilenceIntelligenceEffects,
  SilenceIntelligenceReport,
  SilenceIntelligenceSignal,
  SilenceIntelligenceSignalId,
  SilenceIntelligenceState,
  SilenceIntelligenceSurface,
} from "@/types/silence-intelligence";

import {
  trackReflectionDuringSilence,
  trackReturnAfterSilence,
  trackSilenceStateEntered,
  trackSilenceStateExited,
} from "./silence-intelligence-observation";

const PREF_KEY = "voicememory_silence_intelligence_enabled";
const STATE_KEY = "voicememory_silence_intelligence";
const SESSION_KEY = "voicememory_silence_intelligence_session";
const CHANGE_EVENT = "voicememory:silence-intelligence";

const USER_LINES = [
  "Nothing needs to surface right now.",
  "You can just leave this here.",
] as const;

interface PersistedSilenceIntelligence {
  state: SilenceIntelligenceState;
  enteredAt: string;
  lastSurfacedNoteId: string | null;
  lastSurfacedNoteAt: string | null;
  ignoredNoteCount: number;
  returnAfterSilenceObserved: boolean;
  silenceImprovedRevisit: boolean | null;
  reflectionsDuringSilence: number;
  recentTransitions: Array<{
    from: SilenceIntelligenceState;
    to: SilenceIntelligenceState;
    at: string;
  }>;
  lastResolvedAt: string | null;
  suppressedThisSession: boolean;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function defaultPersisted(): PersistedSilenceIntelligence {
  return {
    state: "normal",
    enteredAt: new Date().toISOString(),
    lastSurfacedNoteId: null,
    lastSurfacedNoteAt: null,
    ignoredNoteCount: 0,
    returnAfterSilenceObserved: false,
    silenceImprovedRevisit: null,
    reflectionsDuringSilence: 0,
    recentTransitions: [],
    lastResolvedAt: null,
    suppressedThisSession: false,
  };
}

function readPersisted(): PersistedSilenceIntelligence {
  if (!isBrowser()) return defaultPersisted();
  try {
    const raw = localStorage.getItem(STATE_KEY);
    if (!raw) return defaultPersisted();
    return { ...defaultPersisted(), ...(JSON.parse(raw) as Partial<PersistedSilenceIntelligence>) };
  } catch {
    return defaultPersisted();
  }
}

function writePersisted(state: PersistedSilenceIntelligence): void {
  if (!isBrowser()) return;
  localStorage.setItem(STATE_KEY, JSON.stringify(state));
}

export function isSilenceIntelligenceEnabled(): boolean {
  if (!isBrowser()) return true;
  return localStorage.getItem(PREF_KEY) !== "0";
}

export function setSilenceIntelligenceEnabled(enabled: boolean): void {
  if (!isBrowser()) return;
  if (enabled) {
    localStorage.removeItem(PREF_KEY);
  } else {
    localStorage.setItem(PREF_KEY, "0");
  }
  window.dispatchEvent(new CustomEvent(CHANGE_EVENT));
}

function effectsForState(state: SilenceIntelligenceState): SilenceIntelligenceEffects {
  switch (state) {
    case "almost_silent":
      return {
        suppressMemoryNotes: true,
        suppressFollowups: true,
        suppressRoundupPrompts: true,
        suppressEmotionalProof: true,
        delayResurfacing: true,
        essentialsOnly: true,
      };
    case "very_quiet":
      return {
        suppressMemoryNotes: true,
        suppressFollowups: true,
        suppressRoundupPrompts: true,
        suppressEmotionalProof: true,
        delayResurfacing: true,
        essentialsOnly: false,
      };
    case "quiet":
      return {
        suppressMemoryNotes: false,
        suppressFollowups: true,
        suppressRoundupPrompts: false,
        suppressEmotionalProof: false,
        delayResurfacing: true,
        essentialsOnly: false,
      };
    default:
      return {
        suppressMemoryNotes: false,
        suppressFollowups: false,
        suppressRoundupPrompts: false,
        suppressEmotionalProof: false,
        delayResurfacing: false,
        essentialsOnly: false,
      };
  }
}

function stateFromScore(score: number): SilenceIntelligenceState {
  if (score >= 7) return "almost_silent";
  if (score >= 5) return "very_quiet";
  if (score >= 3) return "quiet";
  return "normal";
}

function signal(
  id: SilenceIntelligenceSignalId,
  label: string,
  detail: string,
  weight: number,
): SilenceIntelligenceSignal {
  return { id, label, detail, weight };
}

function detectRecordOnlyPreference(entries: JournalEntry[]): SilenceIntelligenceSignal | null {
  if (isListeningModeEnabled()) {
    return signal(
      "record_only_preference",
      "Record-only preference",
      "Listening mode is on",
      2,
    );
  }

  const recent = [...entries]
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
    .slice(0, 6);
  if (recent.length < 3) return null;

  const pending = recent.filter((entry) => entry.reflectionPending === true).length;
  if (pending >= Math.ceil(recent.length * 0.6)) {
    return signal(
      "record_only_preference",
      "Record-only preference",
      `${pending} of last ${recent.length} entries left as recordings`,
      2,
    );
  }

  return null;
}

function detectHeavyEntriesLowAction(entries: JournalEntry[]): SilenceIntelligenceSignal | null {
  const heavy = entries.filter((entry) => entry.reflection.emotionalIntensity >= 68);
  if (heavy.length === 0) return null;

  const events = readRetentionLoopEvents();
  const heavyIds = new Set(heavy.map((entry) => entry.id));
  const revisits = events.filter(
    (event) =>
      (event.kind === "entry_revisited" || event.kind === "old_entry_opened_from_note") &&
      event.entryId &&
      heavyIds.has(event.entryId),
  );
  const reflections = events.filter(
    (event) =>
      (event.kind === "followup_recording_completed" || event.kind === "bookmark_created") &&
      event.entryId &&
      heavyIds.has(event.entryId),
  );

  if (heavy.length >= 2 && revisits.length >= 2 && reflections.length === 0) {
    return signal(
      "heavy_entries_low_action",
      "Heavy entries, low action",
      `${heavy.length} intense entries with ${revisits.length} revisits and no follow-through`,
      2,
    );
  }

  return null;
}

function detectSignals(entries: JournalEntry[]): SilenceIntelligenceSignal[] {
  const silence = buildSilenceTimingDebugSnapshot();
  const fatigue = detectRevisitFatigue();
  const sacredness = buildSacrednessReport(entries);
  const signals: SilenceIntelligenceSignal[] = [];

  if (
    silence.ignoredCooldownActive ||
    silence.consecutiveIgnored >= 2 ||
    silence.lastTwoWithoutEngagement
  ) {
    signals.push(
      signal(
        "ignored_recent_callbacks",
        "Ignored recent callbacks",
        `${silence.consecutiveIgnored} consecutive ignored · cooldown ${silence.ignoredCooldownActive ? "active" : "off"}`,
        silence.consecutiveIgnored >= 3 ? 3 : 2,
      ),
    );
  }

  if (fatigue.active) {
    signals.push(
      signal(
        "revisit_fatigue",
        "Revisit fatigue",
        `${fatigue.score} revisits in fatigue window`,
        fatigue.score >= 6 ? 3 : 2,
      ),
    );
  }

  if (sacredness.silencePreferred || sacredness.emotionallyCrowded) {
    signals.push(
      signal(
        "emotional_saturation",
        "Emotional saturation",
        sacredness.emotionallyCrowded
          ? "Archive emotionally crowded"
          : "Silence preferred over resurfacing",
        sacredness.emotionallyCrowded ? 3 : 2,
      ),
    );
  }

  if (silence.sessionNoteCount >= 1 || silence.recentShown.length >= 2) {
    const withoutAction = silence.recentShown.filter((row) => !row.actionTaken).length;
    if (withoutAction >= 1 || silence.sessionNoteCount >= 2) {
      signals.push(
        signal(
          "too_many_notes",
          "Too many notes recently",
          `${silence.sessionNoteCount} this session · ${withoutAction} without action`,
          silence.sessionNoteCount >= 2 ? 2 : 1,
        ),
      );
    }
  }

  const recordOnly = detectRecordOnlyPreference(entries);
  if (recordOnly) signals.push(recordOnly);

  const heavyLowAction = detectHeavyEntriesLowAction(entries);
  if (heavyLowAction) signals.push(heavyLowAction);

  const closesWithoutContinuing = silence.recentShown.filter((row) => row.highDwellNoAction).length;
  if (closesWithoutContinuing >= 1) {
    signals.push(
      signal(
        "closes_without_continuing",
        "Closed without continuing",
        `${closesWithoutContinuing} note${closesWithoutContinuing === 1 ? "" : "s"} with dwell but no action`,
        closesWithoutContinuing >= 2 ? 3 : 2,
      ),
    );
  }

  return signals;
}

function computeSilenceImprovedRevisit(
  persisted: PersistedSilenceIntelligence,
  currentState: SilenceIntelligenceState,
): boolean | null {
  if (currentState === "normal") return persisted.silenceImprovedRevisit;

  const events = readRetentionLoopEvents().filter(
    (event) => event.kind === "entry_revisited" || event.kind === "old_entry_opened_from_note",
  );
  if (events.length < 2) return null;

  const enteredDay = toDayKey(persisted.enteredAt);
  const duringSilence = events.filter(
    (event) => daysBetweenKeys(enteredDay, toDayKey(event.at)) >= 0,
  );
  const beforeSilence = events.filter(
    (event) => daysBetweenKeys(toDayKey(event.at), enteredDay) > 0,
  );

  if (duringSilence.length === 0 || beforeSilence.length === 0) return null;
  return duringSilence.length <= beforeSilence.length;
}

function detectReturnAfterSilence(
  persisted: PersistedSilenceIntelligence,
  previousState: SilenceIntelligenceState,
  nextState: SilenceIntelligenceState,
): boolean {
  if (persisted.returnAfterSilenceObserved) return true;
  if (previousState === "normal" && nextState === "normal") return false;

  const daysInSilence = daysBetweenKeys(toDayKey(persisted.enteredAt), todayKey());
  if (daysInSilence < 1) return false;

  const events = readRetentionLoopEvents();
  const recentReturn = events.some(
    (event) =>
      (event.kind === "returned_next_day" ||
        event.kind === "returned_within_7_days" ||
        event.kind === "entry_revisited") &&
      daysBetweenKeys(toDayKey(event.at), todayKey()) <= 2,
  );

  return recentReturn && previousState !== "normal";
}

function pickUserLine(
  state: SilenceIntelligenceState,
  suppressedThisSession: boolean,
): string | null {
  if (state === "normal" || !suppressedThisSession) return null;
  const index = state === "almost_silent" ? 1 : 0;
  return USER_LINES[index] ?? USER_LINES[0];
}

function syncLastSurfacedFromSilence(
  persisted: PersistedSilenceIntelligence,
): PersistedSilenceIntelligence {
  const silence = buildSilenceTimingDebugSnapshot();
  const lastShown = silence.recentShown[silence.recentShown.length - 1];
  if (!lastShown) return persisted;

  const ignoredCount = silence.recentShown.filter((row) => !row.actionTaken).length;
  return {
    ...persisted,
    lastSurfacedNoteId: lastShown.noteId,
    lastSurfacedNoteAt: lastShown.shownAt,
    ignoredNoteCount: ignoredCount,
  };
}

function applyStateTransition(
  persisted: PersistedSilenceIntelligence,
  nextState: SilenceIntelligenceState,
  score: number,
): PersistedSilenceIntelligence {
  const previousState = persisted.state;
  if (previousState === nextState) {
    return {
      ...syncLastSurfacedFromSilence(persisted),
      lastResolvedAt: new Date().toISOString(),
    };
  }

  const now = new Date().toISOString();
  const transitions = [
    ...persisted.recentTransitions,
    { from: previousState, to: nextState, at: now },
  ].slice(-12);

  if (nextState !== "normal" && previousState === "normal") {
    trackSilenceStateEntered(nextState, score);
  } else if (nextState === "normal" && previousState !== "normal") {
    trackSilenceStateExited(previousState, nextState);
  } else if (nextState !== "normal" && previousState !== "normal") {
    trackSilenceStateExited(previousState, nextState);
    trackSilenceStateEntered(nextState, score);
  }

  let returnAfterSilence = persisted.returnAfterSilenceObserved;
  if (!returnAfterSilence && detectReturnAfterSilence(persisted, previousState, nextState)) {
    returnAfterSilence = true;
    trackReturnAfterSilence(nextState);
  }

  return {
    ...syncLastSurfacedFromSilence(persisted),
    state: nextState,
    enteredAt: now,
    recentTransitions: transitions,
    lastResolvedAt: now,
    returnAfterSilenceObserved: returnAfterSilence,
    silenceImprovedRevisit: computeSilenceImprovedRevisit(
      { ...persisted, state: nextState, enteredAt: now },
      nextState,
    ),
  };
}

function resetSessionSuppressionFlag(): void {
  if (!isBrowser()) return;
  if (sessionStorage.getItem(SESSION_KEY)) return;
  sessionStorage.setItem(SESSION_KEY, "1");
  const persisted = readPersisted();
  if (persisted.suppressedThisSession) {
    writePersisted({ ...persisted, suppressedThisSession: false });
  }
}

function buildSilenceIntelligenceReport(
  entries: JournalEntry[],
  persist: boolean,
): SilenceIntelligenceReport {
  if (persist) resetSessionSuppressionFlag();
  const enabled = isSilenceIntelligenceEnabled();
  const persisted = readPersisted();
  const signals = enabled ? detectSignals(entries) : [];
  const score = signals.reduce((sum, row) => sum + row.weight, 0);
  const state = enabled ? stateFromScore(score) : "normal";
  const effects = enabled ? effectsForState(state) : effectsForState("normal");

  const nextPersisted = enabled
    ? persist
      ? applyStateTransition(persisted, state, score)
      : syncLastSurfacedFromSilence({ ...persisted, state })
    : { ...persisted, lastResolvedAt: new Date().toISOString() };

  if (persist) {
    writePersisted(nextPersisted);
  }

  return {
    generatedAt: new Date().toISOString(),
    enabled,
    state: nextPersisted.state,
    score,
    signals,
    effects,
    userLine: enabled ? pickUserLine(nextPersisted.state, nextPersisted.suppressedThisSession) : null,
    lastSurfacedNoteId: nextPersisted.lastSurfacedNoteId,
    lastSurfacedNoteAt: nextPersisted.lastSurfacedNoteAt,
    ignoredNoteCount: nextPersisted.ignoredNoteCount,
    returnAfterSilence: nextPersisted.returnAfterSilenceObserved,
    silenceImprovedRevisit: nextPersisted.silenceImprovedRevisit,
    stateEnteredAt: nextPersisted.enteredAt,
  };
}

/** Resolve silence intelligence — updates persisted state and returns the active report. */
export function resolveSilenceIntelligence(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): SilenceIntelligenceReport {
  return buildSilenceIntelligenceReport(entries, true);
}

export function getSilenceIntelligenceEffects(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): SilenceIntelligenceEffects {
  return buildSilenceIntelligenceReport(entries, false).effects;
}

export function shouldSuppressSilenceIntelligenceSurface(surface: SilenceIntelligenceSurface): boolean {
  if (!isSilenceIntelligenceEnabled()) return false;

  const report = buildSilenceIntelligenceReport(getMemoryEligibleEntries(), false);
  switch (surface) {
    case "memory_note":
      return report.effects.suppressMemoryNotes;
    case "followup":
      return report.effects.suppressFollowups;
    case "roundup_prompt":
      return report.effects.suppressRoundupPrompts;
    case "emotional_proof":
      return report.effects.suppressEmotionalProof;
    case "resurfacing":
      return report.effects.delayResurfacing || report.effects.essentialsOnly;
    default:
      return false;
  }
}

export function markSilenceIntelligenceSuppressed(): void {
  if (!isBrowser()) return;
  const persisted = readPersisted();
  if (persisted.suppressedThisSession) return;
  writePersisted({ ...persisted, suppressedThisSession: true });
}

export function pickSilenceIntelligenceUserLine(): string | null {
  return buildSilenceIntelligenceReport(getMemoryEligibleEntries(), false).userLine;
}

export function recordReflectionDuringSilence(): void {
  if (!isBrowser() || !isSilenceIntelligenceEnabled()) return;
  const persisted = readPersisted();
  if (persisted.state === "normal") return;

  trackReflectionDuringSilence(persisted.state);
  writePersisted({
    ...persisted,
    reflectionsDuringSilence: persisted.reflectionsDuringSilence + 1,
  });
}

export function buildSilenceIntelligenceDebugReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): SilenceIntelligenceDebugReport {
  const report = resolveSilenceIntelligence(entries);
  const persisted = readPersisted();
  const reflectionEvents = readLocalEvents().filter(
    (event) => event.name === "reflection_during_silence",
  ).length;

  return {
    ...report,
    recentStateTransitions: persisted.recentTransitions,
    reflectionsDuringSilence: Math.max(persisted.reflectionsDuringSilence, reflectionEvents),
  };
}

export function clearSilenceIntelligenceState(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(STATE_KEY);
}
