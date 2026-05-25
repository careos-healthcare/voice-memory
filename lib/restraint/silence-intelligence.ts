import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { isListeningModeEnabled } from "@/lib/listening-mode";
import { readLocalEvents } from "@/lib/local-analytics";
import { buildSilenceTimingDebugSnapshot } from "@/lib/refinement/silence-calibration";
import { detectRevisitFatigue } from "@/lib/refinement/revisit-sequencing";
import { scoreMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";
import {
  readSilenceRetentionSignals,
  silenceHarmedFromRetention,
  silenceHelpedFromRetention,
} from "@/lib/restraint/silence-retention-signals";
import { buildSacrednessReport } from "@/lib/restraint/sacredness";
import {
  REVISIT_QUALITY_DURABLE_MIN,
  REVISIT_QUALITY_MEANINGFUL_MIN,
  assessRevisitQuality,
  isRevisitQualityNote,
} from "@/lib/revisit/revisit-quality";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type {
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
  silenceHelpedObserved: boolean;
  silenceHarmedObserved: boolean;
  reflectionsDuringSilence: number;
  recentTransitions: Array<{
    from: SilenceIntelligenceState;
    to: SilenceIntelligenceState;
    at: string;
  }>;
  lastResolvedAt: string | null;
  suppressedThisSession: boolean;
  lastRareResurfacingAt: string | null;
  postReflectionMinimalUntil: string | null;
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
    silenceHelpedObserved: false,
    silenceHarmedObserved: false,
    reflectionsDuringSilence: 0,
    recentTransitions: [],
    lastResolvedAt: null,
    suppressedThisSession: false,
    lastRareResurfacingAt: null,
    postReflectionMinimalUntil: null,
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

function effectsForState(
  state: SilenceIntelligenceState,
  options: {
    allowRareResurfacing: boolean;
    postReflectionMinimal: boolean;
    qualityThresholdRequired: number;
  },
): SilenceIntelligenceEffects {
  const base = (() => {
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
  })();

  return {
    ...base,
    allowRareResurfacing: options.allowRareResurfacing,
    postReflectionMinimal: options.postReflectionMinimal,
    qualityThresholdRequired: options.qualityThresholdRequired,
  };
}

function stateFromScore(
  score: number,
  persisted: PersistedSilenceIntelligence,
  extendQuiet: boolean,
  reduceSuppression: boolean,
): SilenceIntelligenceState {
  const adjusted = reduceSuppression ? Math.max(0, score - 2) : score;
  const candidate = (() => {
    if (adjusted >= 7) return "almost_silent";
    if (adjusted >= 5) return "very_quiet";
    if (adjusted >= 3) return "quiet";
    return "normal";
  })();

  if (!extendQuiet || persisted.state === "normal") {
    return candidate;
  }

  if (persisted.state === "almost_silent" && adjusted >= 5) return "almost_silent";
  if (persisted.state === "very_quiet" && adjusted >= 3) return "very_quiet";
  if (persisted.state === "quiet" && adjusted >= 2) return "quiet";
  return candidate;
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

function detectRetentionSignals(
  entries: JournalEntry[],
  retention: ReturnType<typeof readSilenceRetentionSignals>,
): SilenceIntelligenceSignal[] {
  const signals: SilenceIntelligenceSignal[] = [];

  if (retention.onboardingAhaRate.endsWith("No revisit opens yet")) {
    return signals;
  }

  const ahaMatch = retention.onboardingAhaRate.match(/^(\d+)%/);
  const ahaPct = ahaMatch ? Number(ahaMatch[1]) : 100;
  if (ahaPct < 35) {
    signals.push(
      signal(
        "low_onboarding_aha",
        "Low onboarding aha-rate",
        retention.onboardingAhaRate,
        ahaPct < 15 ? 2 : 1,
      ),
    );
  }

  if (retention.ignoredPromptCount >= 2) {
    signals.push(
      signal(
        "ignored_gentle_prompts",
        "Ignored gentle prompts",
        `${retention.ignoredPromptCount} ignored return prompts`,
        retention.ignoredPromptCount >= 3 ? 3 : 2,
      ),
    );
  }

  if (
    retention.voluntaryReturnCount === 0 &&
    retention.returnAfterSilenceCount === 0 &&
    retention.reflectionDuringSilenceCount === 0
  ) {
    signals.push(
      signal(
        "weak_return_triggers",
        "Weak return triggers",
        "No voluntary or silence-attributed returns yet",
        1,
      ),
    );
  }

  if (retention.highQualityRevisitAvailable) {
    signals.push(
      signal(
        "high_quality_revisit_available",
        "High-quality revisit available",
        `Best revisit score ${retention.bestRevisitScore ?? "—"} — rare resurfacing may be allowed`,
        -1,
      ),
    );
  }

  if (retention.exportBackupDuringSilence) {
    signals.push(
      signal(
        "archive_care_during_silence",
        "Archive care during silence",
        "Export or backup used while quiet — user still tending the archive",
        -1,
      ),
    );
  }

  return signals;
}

function detectSignals(
  entries: JournalEntry[],
  retention: ReturnType<typeof readSilenceRetentionSignals>,
  silenceHelped: boolean,
  silenceHarmed: boolean,
): SilenceIntelligenceSignal[] {
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

  signals.push(...detectRetentionSignals(entries, retention));

  if (silenceHelped) {
    signals.push(
      signal(
        "silence_helped_return",
        "Silence helped return behavior",
        "Return, reflection, or archive care observed after quiet",
        2,
      ),
    );
  }

  if (silenceHarmed) {
    signals.push(
      signal(
        "silence_harmed_behavior",
        "Silence may be harming return",
        "Extended quiet without payoff — easing suppression",
        -2,
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
  silenceHelped: boolean,
  silenceHarmed: boolean,
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
    silenceHelpedObserved: silenceHelped,
    silenceHarmedObserved: silenceHarmed,
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

function isPostReflectionMinimal(persisted: PersistedSilenceIntelligence): boolean {
  if (!persisted.postReflectionMinimalUntil) return false;
  return Date.now() < new Date(persisted.postReflectionMinimalUntil).getTime();
}

function canAllowRareResurfacing(
  persisted: PersistedSilenceIntelligence,
  retention: ReturnType<typeof readSilenceRetentionSignals>,
): boolean {
  if (persisted.state === "normal") return false;
  if (!retention.highQualityRevisitAvailable) return false;
  if (persisted.lastRareResurfacingAt) {
    const usedAfterEntering =
      daysBetweenKeys(toDayKey(persisted.enteredAt), toDayKey(persisted.lastRareResurfacingAt)) >= 0;
    if (usedAfterEntering) return false;
  }
  return true;
}

function qualityThresholdForState(
  state: SilenceIntelligenceState,
  retention: ReturnType<typeof readSilenceRetentionSignals>,
): number {
  if (retention.bestRevisitScore !== null && retention.bestRevisitScore >= REVISIT_QUALITY_DURABLE_MIN) {
    return REVISIT_QUALITY_DURABLE_MIN;
  }
  if (state === "almost_silent") return REVISIT_QUALITY_DURABLE_MIN;
  if (state === "very_quiet") return REVISIT_QUALITY_MEANINGFUL_MIN + 4;
  return REVISIT_QUALITY_MEANINGFUL_MIN;
}

function computeNextResurfacingWindow(
  state: SilenceIntelligenceState,
  extendQuiet: boolean,
  allowRare: boolean,
): string | null {
  if (state === "normal") return "Now";
  if (allowRare) return "Rare high-quality moment allowed now";
  if (state === "almost_silent") return extendQuiet ? "7+ days unless reflection during silence" : "5–7 days";
  if (state === "very_quiet") return extendQuiet ? "3–5 days" : "2–4 days";
  return extendQuiet ? "1–3 days" : "Next session";
}

function listSuppressedSurfaces(effects: SilenceIntelligenceEffects): string[] {
  const rows: string[] = [];
  if (effects.suppressMemoryNotes && !effects.allowRareResurfacing) {
    rows.push("memory_note");
  }
  if (effects.suppressFollowups || effects.postReflectionMinimal) rows.push("followup");
  if (effects.suppressRoundupPrompts) rows.push("roundup_prompt");
  if (effects.suppressEmotionalProof || effects.postReflectionMinimal) rows.push("emotional_proof");
  if (effects.delayResurfacing || effects.essentialsOnly) rows.push("resurfacing");
  if (effects.allowRareResurfacing) rows.push("rare_resurfacing_allowed");
  if (effects.postReflectionMinimal) rows.push("post_reflection_minimal");
  return rows;
}

function buildActivationReason(signals: SilenceIntelligenceSignal[]): string {
  if (signals.length === 0) return "No active silence signals.";
  const positive = signals.filter((row) => row.weight > 0).slice(0, 3);
  if (positive.length === 0) {
    return signals[0]?.label ?? "Retention-adjusted quiet state.";
  }
  return positive.map((row) => row.label).join(" · ");
}

function buildSilenceIntelligenceReport(
  entries: JournalEntry[],
  persist: boolean,
): SilenceIntelligenceReport {
  if (persist) resetSessionSuppressionFlag();
  const enabled = isSilenceIntelligenceEnabled();
  const persisted = readPersisted();
  const retention = readSilenceRetentionSignals(
    entries,
    persisted.state === "normal" ? null : persisted.enteredAt,
  );

  const daysInState =
    persisted.state === "normal"
      ? 0
      : daysBetweenKeys(toDayKey(persisted.enteredAt), todayKey());

  const silenceHelped =
    persisted.silenceHelpedObserved ||
    silenceHelpedFromRetention(
      retention,
      persisted.returnAfterSilenceObserved,
      persisted.silenceImprovedRevisit,
    );

  const silenceHarmed =
    persisted.silenceHarmedObserved ||
    silenceHarmedFromRetention(
      retention,
      persisted.state,
      daysInState,
      persisted.returnAfterSilenceObserved,
    );

  const signals = enabled
    ? detectSignals(entries, retention, silenceHelped, silenceHarmed)
    : [];
  const score = signals.reduce((sum, row) => sum + row.weight, 0);
  const state = enabled
    ? stateFromScore(score, persisted, silenceHelped, silenceHarmed)
    : "normal";

  const postReflectionMinimal = isPostReflectionMinimal(persisted);
  const allowRareResurfacing = canAllowRareResurfacing(persisted, retention);
  const qualityThresholdRequired = qualityThresholdForState(state, retention);

  const effects = enabled
    ? effectsForState(state, {
        allowRareResurfacing,
        postReflectionMinimal,
        qualityThresholdRequired,
      })
    : effectsForState("normal", {
        allowRareResurfacing: false,
        postReflectionMinimal: false,
        qualityThresholdRequired: REVISIT_QUALITY_MEANINGFUL_MIN,
      });

  if (postReflectionMinimal) {
    effects.suppressMemoryNotes = true;
    effects.suppressFollowups = true;
    effects.suppressEmotionalProof = true;
    effects.delayResurfacing = true;
  }

  const nextPersisted = enabled
    ? persist
      ? applyStateTransition(persisted, state, score, silenceHelped, silenceHarmed)
      : syncLastSurfacedFromSilence({
          ...persisted,
          state,
          silenceHelpedObserved: silenceHelped,
          silenceHarmedObserved: silenceHarmed,
        })
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

  if (report.effects.postReflectionMinimal) {
    switch (surface) {
      case "memory_note":
      case "followup":
      case "emotional_proof":
      case "resurfacing":
        return true;
      case "roundup_prompt":
        return report.effects.suppressRoundupPrompts;
      default:
        return false;
    }
  }

  if (
    (surface === "memory_note" || surface === "resurfacing") &&
    report.effects.allowRareResurfacing
  ) {
    return false;
  }

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

export function noteQualifiesForRareSilenceResurfacing(
  note: MemoryNote,
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): boolean {
  const report = buildSilenceIntelligenceReport(entries, false);
  if (!report.effects.allowRareResurfacing) return false;

  if (isRevisitQualityNote(note)) {
    const verdict = assessRevisitQuality(note, entries);
    return verdict.protected || verdict.total >= report.effects.qualityThresholdRequired;
  }

  return scoreMemoryHierarchy(note, entries).total >= report.effects.qualityThresholdRequired;
}

export function markRareResurfacingUsed(): void {
  if (!isBrowser()) return;
  const persisted = readPersisted();
  writePersisted({
    ...persisted,
    lastRareResurfacingAt: new Date().toISOString(),
  });
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
  const minimalUntil = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  writePersisted({
    ...persisted,
    reflectionsDuringSilence: persisted.reflectionsDuringSilence + 1,
    postReflectionMinimalUntil: minimalUntil,
    silenceHelpedObserved: true,
  });
}

export function buildSilenceIntelligenceDebugReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): import("@/types/silence-intelligence").SilenceIntelligenceDebugReport {
  const report = resolveSilenceIntelligence(entries);
  const persisted = readPersisted();
  const reflectionEvents = readLocalEvents().filter(
    (event) => event.name === "reflection_during_silence",
  ).length;
  const retention = readSilenceRetentionSignals(
    entries,
    persisted.state === "normal" ? null : persisted.enteredAt,
  );
  const silenceHelped =
    persisted.silenceHelpedObserved ||
    silenceHelpedFromRetention(
      retention,
      persisted.returnAfterSilenceObserved,
      persisted.silenceImprovedRevisit,
    );
  const silenceHarmed =
    persisted.silenceHarmedObserved ||
    silenceHarmedFromRetention(
      retention,
      persisted.state,
      persisted.state === "normal"
        ? 0
        : daysBetweenKeys(toDayKey(persisted.enteredAt), todayKey()),
      persisted.returnAfterSilenceObserved,
    );

  return {
    ...report,
    recentStateTransitions: persisted.recentTransitions,
    reflectionsDuringSilence: Math.max(persisted.reflectionsDuringSilence, reflectionEvents),
    activationReason: buildActivationReason(report.signals),
    suppressedSurfaces: listSuppressedSurfaces(report.effects),
    silenceHelped,
    silenceHarmed,
    nextResurfacingWindow: computeNextResurfacingWindow(
      report.state,
      silenceHelped,
      report.effects.allowRareResurfacing,
    ),
    retentionSignals: retention,
  };
}

export function clearSilenceIntelligenceState(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(STATE_KEY);
}
