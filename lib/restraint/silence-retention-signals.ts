import { LAUNCH_EVENTS, readLocalEvents } from "@/lib/local-analytics";
import {
  RETURN_TRIGGER_EVENTS,
  countReturnTriggerEvents,
} from "@/lib/retention/return-triggers";
import {
  REVISIT_QUALITY_MEANINGFUL_MIN,
  assessRevisitQuality,
  collectRevisitQualityCandidates,
} from "@/lib/revisit/revisit-quality";
import type { JournalEntry } from "@/types/journal";
import type { SilenceIntelligenceRetentionSignals } from "@/types/silence-intelligence";

const PROMPT_STATE_KEY = "voicememory_first_week_prompt_state";

function readIgnoredPromptCount(): number {
  if (typeof window === "undefined") return 0;
  try {
    const raw = localStorage.getItem(PROMPT_STATE_KEY);
    if (!raw) return 0;
    const parsed = JSON.parse(raw) as { ignoredCount?: number };
    return parsed.ignoredCount ?? 0;
  } catch {
    return 0;
  }
}

function onboardingAhaRateLabel(): string {
  const events = readLocalEvents();
  const revisits =
    events.filter((event) => event.name === "revisit_opened").length +
    events.filter((event) => event.name === "first_session_old_reflection_opened").length;
  const aha = events.filter((event) => event.name === "first_aha_moment").length;
  if (revisits === 0) return "No revisit opens yet";
  return `${Math.round((aha / revisits) * 100)}% (${aha}/${revisits})`;
}

function exportBackupDuringSilence(silenceEnteredAt: string | null): boolean {
  if (!silenceEnteredAt) return false;
  const enteredMs = new Date(silenceEnteredAt).getTime();
  return readLocalEvents().some((event) => {
    if (
      event.name !== LAUNCH_EVENTS.exportUsed &&
      event.name !== "backup_after_premium" &&
      event.name !== RETURN_TRIGGER_EVENTS.returnAfterBackup &&
      event.name !== RETURN_TRIGGER_EVENTS.returnAfterArchiveExport
    ) {
      return false;
    }
    return new Date(event.at).getTime() >= enteredMs;
  });
}

export function readSilenceRetentionSignals(
  entries: JournalEntry[],
  silenceEnteredAt: string | null,
): SilenceIntelligenceRetentionSignals {
  const events = readLocalEvents();
  const returnCounts = countReturnTriggerEvents();
  const candidates = collectRevisitQualityCandidates(entries);
  const bestVerdict = candidates
    .map((note) => assessRevisitQuality(note, entries))
    .sort((a, b) => b.total - a.total)[0];

  return {
    onboardingAhaRate: onboardingAhaRateLabel(),
    returnAfterSilenceCount:
      returnCounts[RETURN_TRIGGER_EVENTS.returnAfterSilence] ??
      events.filter((event) => event.name === RETURN_TRIGGER_EVENTS.returnAfterSilence).length,
    reflectionDuringSilenceCount: events.filter(
      (event) => event.name === "reflection_during_silence",
    ).length,
    revisitAfterSilenceCount: events.filter(
      (event) =>
        event.name === "revisit_opened" &&
        silenceEnteredAt &&
        new Date(event.at).getTime() >= new Date(silenceEnteredAt).getTime(),
    ).length,
    ignoredPromptCount: readIgnoredPromptCount(),
    highQualityRevisitAvailable: Boolean(
      bestVerdict &&
        (bestVerdict.protected || bestVerdict.total >= REVISIT_QUALITY_MEANINGFUL_MIN),
    ),
    bestRevisitScore: bestVerdict?.total ?? null,
    exportBackupDuringSilence: exportBackupDuringSilence(silenceEnteredAt),
    voluntaryReturnCount: returnCounts[RETURN_TRIGGER_EVENTS.returnWithoutPrompt] ?? 0,
  };
}

export function silenceHelpedFromRetention(
  retention: SilenceIntelligenceRetentionSignals,
  returnAfterSilenceObserved: boolean,
  silenceImprovedRevisit: boolean | null,
): boolean {
  if (returnAfterSilenceObserved) return true;
  if (silenceImprovedRevisit === true) return true;
  if (retention.returnAfterSilenceCount > 0 && retention.reflectionDuringSilenceCount > 0) {
    return true;
  }
  if (retention.exportBackupDuringSilence && retention.reflectionDuringSilenceCount > 0) {
    return true;
  }
  return false;
}

export function silenceHarmedFromRetention(
  retention: SilenceIntelligenceRetentionSignals,
  state: string,
  daysInState: number,
  returnAfterSilenceObserved: boolean,
): boolean {
  if (state === "normal") return false;

  const noPayoff =
    retention.returnAfterSilenceCount === 0 &&
    retention.reflectionDuringSilenceCount === 0 &&
    retention.revisitAfterSilenceCount === 0 &&
    !returnAfterSilenceObserved;

  if (daysInState >= 5 && noPayoff && retention.ignoredPromptCount >= 2) {
    return true;
  }

  if (daysInState >= 7 && noPayoff) {
    return true;
  }

  const events = readLocalEvents();
  const instantAbandon = events.filter((event) => event.name === "roundup_instant_abandon").length;
  if (instantAbandon >= 2 && retention.voluntaryReturnCount === 0 && daysInState >= 3) {
    return true;
  }

  return false;
}
