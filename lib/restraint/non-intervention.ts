import { buildSilenceTimingDebugSnapshot } from "@/lib/refinement/silence-calibration";
import { buildRevisitSequencingReport } from "@/lib/refinement/revisit-sequencing";
import { buildSacrednessReport } from "@/lib/restraint/sacredness";
import { getSilenceFirstPolicy } from "@/lib/restraint/silence-first";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { toDayKey, daysBetweenKeys, todayKey } from "@/lib/dates";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { NonInterventionReport } from "@/types/sacredness-layer";

const NON_INTERVENTION_KEY = "voicememory_non_intervention_log";
const MAX_LOG = 40;

interface NonInterventionLogEntry {
  at: string;
  kind: "silence" | "revisit_after_silence" | "delayed_effective";
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readLog(): NonInterventionLogEntry[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(NON_INTERVENTION_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as NonInterventionLogEntry[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function appendLog(entry: NonInterventionLogEntry): void {
  if (!isBrowser()) return;
  const next = [...readLog(), entry].slice(-MAX_LOG);
  localStorage.setItem(NON_INTERVENTION_KEY, JSON.stringify(next));
}

export function recordNonInterventionSilence(): void {
  appendLog({ at: new Date().toISOString(), kind: "silence" });
}

export function recordRevisitAfterSilence(): void {
  appendLog({ at: new Date().toISOString(), kind: "revisit_after_silence" });
}

export function recordDelayedCallbackEffective(): void {
  appendLog({ at: new Date().toISOString(), kind: "delayed_effective" });
}

/** Sometimes nothing should surface — silence is emotionally correct. */
export function buildNonInterventionReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): NonInterventionReport {
  const sacredness = buildSacrednessReport(entries);
  const silenceFirst = getSilenceFirstPolicy(entries);
  const silence = buildSilenceTimingDebugSnapshot();
  const sequencing = buildRevisitSequencingReport();
  const log = readLog();
  const loopEvents = readRetentionLoopEvents();

  const conclusions: NonInterventionReport["conclusions"] = [];

  if (silenceFirst.active || sacredness.silencePreferred) {
    conclusions.push({
      id: "surface-nothing",
      text: "Nothing should surface right now",
      confidence: sacredness.silenceValueScore,
    });
  }

  if (sacredness.silenceValueScore >= 50) {
    conclusions.push({
      id: "silence-correct",
      text: "Silence is more emotionally correct",
      confidence: sacredness.silenceValueScore,
    });
  }

  if (sacredness.emotionallyCrowded || sacredness.meaningfulnessInflated) {
    conclusions.push({
      id: "no-interpretation",
      text: "The archive does not need interpretation",
      confidence: Math.min(90, 50 + sacredness.inflationWarnings.length * 8),
    });
  }

  if (sequencing.revisitFatigueActive && silence.weakNoteSuppressed) {
    conclusions.push({
      id: "stay-untouched",
      text: "This moment should stay untouched",
      confidence: 72,
    });
  }

  const silenceEvents = log.filter((e) => e.kind === "silence").length;
  const revisitAfter = log.filter((e) => e.kind === "revisit_after_silence").length;
  const delayedEffective = log.filter((e) => e.kind === "delayed_effective").length;

  const recentRevisits = loopEvents.filter(
    (e) =>
      (e.kind === "entry_revisited" || e.kind === "old_entry_opened_from_note") &&
      daysBetweenKeys(toDayKey(e.at), todayKey()) <= 14,
  ).length;

  const silenceSuccessRate =
    silenceEvents > 0 ? Math.min(100, Math.round((revisitAfter / silenceEvents) * 100)) : 0;

  const delayedCallbackEffectiveness =
    delayedEffective > 0
      ? Math.min(100, delayedEffective * 25)
      : recentRevisits > 0 && silence.ignoredCooldownActive
        ? 40
        : 0;

  const shouldSurfaceNothing =
    conclusions.some((c) => c.id === "surface-nothing") && sacredness.silenceValueScore >= 45;

  return {
    generatedAt: new Date().toISOString(),
    hasData: entries.length > 0 || log.length > 0,
    shouldSurfaceNothing,
    conclusions,
    silenceSuccessRate,
    revisitAfterSilenceCount: revisitAfter,
    delayedCallbackEffectiveness,
  };
}
