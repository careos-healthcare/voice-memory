import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { readBeliefTimelineHistory } from "@/lib/archive/belief-timeline-storage";
import {
  detectLifeAreas,
  LIFE_AREA_LABELS,
  type LifeAreaLabel,
} from "@/lib/blind-spots/blind-spot-ranking";
import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { RESURFACING_MIN_ABSENCE_DAYS } from "@/lib/memory/resurfacing-priority";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { assertNoCertaintyLanguage } from "@/lib/theories/theory-confidence-movement";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveSilenceSignal, ArchiveSilenceView } from "@/types/archive-silence";
import type { JournalEntry } from "@/types/journal";
import type { Theory } from "@/types/theory";

export const ARCHIVE_SILENCE_TITLE = "Meaningful absence";

const MIN_ABSENCE_DAYS = RESURFACING_MIN_ABSENCE_DAYS;
const MIN_PHRASE_COUNT = 3;
const MIN_LIFE_AREA_MENTIONS = 2;
const MAX_SIGNALS = 5;

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function pickLeadTheory(theories: Theory[]): Theory | null {
  if (theories.length === 0) return null;
  const active = theories.filter(
    (t) => t.status === "active" || t.status === "strengthening" || t.status === "weakening",
  );
  const pool = active.length > 0 ? active : theories;
  return pool.slice().sort((a, b) => b.confidence - a.confidence)[0] ?? null;
}

export function beliefEvidenceGapLine(days: number): string {
  return `The archive has not seen evidence for this belief in ${days} day${days === 1 ? "" : "s"}.`;
}

export function lifeAreaAbsentLine(area: string, days: number): string {
  return `The archive has not seen evidence from ${area} in ${days} day${days === 1 ? "" : "s"}.`;
}

export const PATTERN_FADING_LINE = "This pattern may be fading.";

function pushSignal(
  signals: ArchiveSilenceSignal[],
  signal: ArchiveSilenceSignal,
): void {
  assertNoCertaintyLanguage(signal.text);
  if (signals.some((row) => row.text === signal.text)) return;
  signals.push(signal);
}

function lastBeliefEvidenceDayKey(theory: Theory, entries: JournalEntry[]): string | null {
  const entryById = new Map(entries.map((entry) => [entry.id, entry]));
  let latest: string | null = null;

  for (const quote of [...theory.supportingEvidence, ...theory.contradictingEvidence]) {
    const entry = entryById.get(quote.entryId);
    if (!entry) continue;
    const key = toDayKey(entry.createdAt);
    if (!latest || key > latest) latest = key;
  }

  const history = readBeliefTimelineHistory(theory.id);
  const lastHistory = history[history.length - 1];
  if (lastHistory?.at) {
    const historyKey = toDayKey(lastHistory.at);
    if (!latest || historyKey > latest) latest = historyKey;
  }

  return latest;
}

function detectBeliefEvidenceGap(
  entries: JournalEntry[],
  signals: ArchiveSilenceSignal[],
): void {
  const belief = buildArchiveBeliefView(entries);
  if (!belief) return;

  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const theory =
    report.all.find((row) => row.id === belief.theoryId) ?? pickLeadTheory(report.all);
  if (!theory) return;

  const lastKey = lastBeliefEvidenceDayKey(theory, entries);
  if (!lastKey) return;

  const days = daysBetweenKeys(lastKey, todayKey());
  if (days < MIN_ABSENCE_DAYS) return;

  pushSignal(signals, {
    id: "archive-silence-belief",
    kind: "belief_evidence_gap",
    text: beliefEvidenceGapLine(days),
  });
}

function entryLifeAreas(entry: JournalEntry): LifeAreaLabel[] {
  const blob = [
    entry.transcript,
    entry.reflection.recurringThemes.join(" "),
    entry.reflection.repeatedSignal ?? "",
    entry.reflection.concreteObservation ?? "",
  ].join(" ");
  return detectLifeAreas(blob);
}

function detectLifeAreaAbsence(
  entries: JournalEntry[],
  signals: ArchiveSilenceSignal[],
): void {
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );

  const rows: Array<{ area: LifeAreaLabel; dayKey: string }> = [];
  for (const entry of sorted) {
    for (const area of entryLifeAreas(entry)) {
      rows.push({ area, dayKey: toDayKey(entry.createdAt) });
    }
  }

  for (const area of LIFE_AREA_LABELS) {
    const mentions = rows.filter((row) => row.area === area);
    if (mentions.length < MIN_LIFE_AREA_MENTIONS) continue;

    const lastKey = mentions[mentions.length - 1]!.dayKey;
    const days = daysBetweenKeys(lastKey, todayKey());
    if (days < MIN_ABSENCE_DAYS) continue;

    pushSignal(signals, {
      id: `archive-silence-area-${area}`,
      kind: "life_area_absent",
      text: lifeAreaAbsentLine(area.toLowerCase(), days),
    });
  }
}

function detectPatternFading(
  entries: JournalEntry[],
  signals: ArchiveSilenceSignal[],
): void {
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );

  for (const phrase of buildPhraseMemory(sorted)) {
    if (phrase.count < MIN_PHRASE_COUNT) continue;
    const last = phrase.occurrences[phrase.occurrences.length - 1];
    if (!last) continue;

    const days = daysBetweenKeys(last.dateKey, todayKey());
    if (days < MIN_ABSENCE_DAYS) continue;

    pushSignal(signals, {
      id: `archive-silence-pattern-${phrase.phrase}`,
      kind: "pattern_fading",
      text: PATTERN_FADING_LINE,
    });
    return;
  }
}

/** Surface meaningful absence from timeline, life areas, and phrase memory. */
export function buildArchiveSilenceView(
  entriesInput?: JournalEntry[],
): ArchiveSilenceView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  if (entries.length < 3) return null;

  const signals: ArchiveSilenceSignal[] = [];
  detectBeliefEvidenceGap(entries, signals);
  detectLifeAreaAbsence(entries, signals);
  detectPatternFading(entries, signals);

  if (signals.length === 0) return null;

  const ordered = signals.sort((a, b) => {
    const rank = (kind: ArchiveSilenceSignal["kind"]) => {
      if (kind === "belief_evidence_gap") return 0;
      if (kind === "life_area_absent") return 1;
      return 2;
    };
    return rank(a.kind) - rank(b.kind);
  });

  return { signals: ordered.slice(0, MAX_SIGNALS) };
}
