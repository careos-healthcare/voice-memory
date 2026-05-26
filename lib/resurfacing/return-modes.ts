import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { linkedEntriesForNote } from "@/lib/refinement/note-linked-entries";
import { quoteSimilarity } from "@/lib/refinement/then-vs-now-quotes";
import { readLocalEvents } from "@/lib/local-analytics";
import { assessResurfacingWhyNow } from "@/lib/revisit/resurfacing-why-now";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

import type { ResurfacingReturnMode } from "@/types/resurfacing-variety";

export type { ResurfacingReturnMode };

export const RESURFACING_RETURN_MODES: readonly ResurfacingReturnMode[] = [
  "exact_echo",
  "contradiction",
  "silence_gap",
  "escalation",
  "recurrence_observation",
];

export const RESURFACING_MODE_WINDOW = 5;

export const RESURFACING_MODE_EVENTS = {
  shown: "resurfacing_mode_shown",
  opened: "resurfacing_mode_opened",
  reflectionAfter: "reflection_after_mode",
} as const;

const CAME_BACK_RE = /\byou came back\b/i;
const ESCALATION_RE =
  /\b(more weight|more pressure|heavier|intensified|got louder|harder now|worse now|escalat)\b/i;
const CONTRAST_RE =
  /\b(sound different|reads differently|quieter than|heavier than|less tension|more direct|used to feel|this time sounds|changed since)\b/i;
const SILENCE_GAP_RE =
  /\b(for a while|had not|quiet stretch|days ago|weeks ago|after a gap|not named for|not appeared for)\b/i;

export const RESURFACING_MODE_LABELS: Record<ResurfacingReturnMode, string> = {
  exact_echo: "Exact echo",
  contradiction: "Contradiction",
  silence_gap: "Silence gap",
  escalation: "Escalation",
  recurrence_observation: "Recurrence observation",
};

function gapDaysForNote(note: MemoryNote, entries: JournalEntry[]): number {
  const linked = linkedEntriesForNote(note, entries);
  if (linked.length < 2) return 0;
  const sorted = [...linked].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  return daysBetweenKeys(
    toDayKey(sorted[0].createdAt),
    toDayKey(sorted[sorted.length - 1].createdAt),
  );
}

function quoteEchoStrength(note: MemoryNote): number {
  if (!note.pastQuote?.trim() || !note.currentQuote?.trim()) return 0;
  return quoteSimilarity(note.pastQuote, note.currentQuote);
}

/** Classify which return mode a resurfacing line expresses. */
export function classifyResurfacingReturnMode(
  note: MemoryNote,
  entries: JournalEntry[],
): ResurfacingReturnMode {
  const text = note.text.trim();
  const gap = gapDaysForNote(note, entries);
  const echo = quoteEchoStrength(note);
  const whyNow = assessResurfacingWhyNow(note, entries);

  if (
    echo >= 0.72 ||
    note.id.includes("phrase") ||
    note.id.includes("echo") ||
    /\b(said something similar|same words|similar words again)\b/i.test(text)
  ) {
    return "exact_echo";
  }

  if (
    (note.pastQuote?.trim() && note.currentQuote?.trim() && echo < 0.55) ||
    CONTRAST_RE.test(text) ||
    whyNow.primaryKind === "mood_shift_same_topic"
  ) {
    return "contradiction";
  }

  if (
    gap >= 7 ||
    SILENCE_GAP_RE.test(text) ||
    whyNow.primaryKind === "quiet_gap_return"
  ) {
    return "silence_gap";
  }

  const linked = linkedEntriesForNote(note, entries);
  if (linked.length >= 2) {
    const intensities = linked.map((e) => e.reflection.emotionalIntensity);
    const delta = Math.max(...intensities) - Math.min(...intensities);
    if (delta >= 1.2 && ESCALATION_RE.test(text)) {
      return "escalation";
    }
  }
  if (ESCALATION_RE.test(text) || /\bmore (weight|pressure|tension)\b/i.test(text)) {
    return "escalation";
  }

  return "recurrence_observation";
}

export function cadenceKey(text: string): string {
  const words = text
    .trim()
    .toLowerCase()
    .replace(/[^\w\s]/g, "")
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 4);
  return words.join(" ") || "empty";
}

export function emotionalStructureKey(note: MemoryNote): string {
  const text = note.text.toLowerCase();
  const tags: string[] = [note.category];
  if (/\b(heavier|weight|pressure|anxious|scared)\b/.test(text)) tags.push("weight");
  if (/\b(quieter|calmer|lighter|settled)\b/.test(text)) tags.push("ease");
  if (/\b(direct|blunt|clearer)\b/.test(text)) tags.push("direct");
  if (/\b(circling|loop|again|return)\b/.test(text)) tags.push("loop");
  if (note.pastQuote && note.currentQuote) tags.push("quoted_pair");
  return tags.sort().join("|");
}

export function getRecentResurfacingModes(
  window = RESURFACING_MODE_WINDOW,
): ResurfacingReturnMode[] {
  const modes: ResurfacingReturnMode[] = [];
  for (const event of [...readLocalEvents()].reverse()) {
    if (event.name !== RESURFACING_MODE_EVENTS.shown) continue;
    const mode = event.meta?.mode as ResurfacingReturnMode | undefined;
    if (!mode || !RESURFACING_RETURN_MODES.includes(mode)) continue;
    modes.push(mode);
    if (modes.length >= window) break;
  }
  return modes;
}

export function isReturnModeBlocked(
  mode: ResurfacingReturnMode,
  recent = getRecentResurfacingModes(),
): boolean {
  return recent.includes(mode);
}

export function filterCallbacksByModeDiversity(
  notes: MemoryNote[],
  entries: JournalEntry[],
  recent = getRecentResurfacingModes(),
): MemoryNote[] {
  const diverse = notes.filter(
    (note) => !isReturnModeBlocked(classifyResurfacingReturnMode(note, entries), recent),
  );
  return diverse.length > 0 ? diverse : notes;
}

/** Fatigue weighting — situational variety over template reuse. */
export function getReturnModeFatiguePenalty(
  note: MemoryNote,
  entries: JournalEntry[],
): number {
  let penalty = 0;
  const text = note.text.trim();
  const mode = classifyResurfacingReturnMode(note, entries);
  const recent = getRecentResurfacingModes();

  if (recent.includes(mode)) penalty += 48;

  const cadence = cadenceKey(text);
  const structure = emotionalStructureKey(note);
  const recentShown = [...readLocalEvents()]
    .reverse()
    .filter((e) => e.name === RESURFACING_MODE_EVENTS.shown)
    .slice(0, RESURFACING_MODE_WINDOW);

  for (const event of recentShown) {
    if (event.meta?.cadence === cadence) penalty += 14;
    if (event.meta?.structure === structure) penalty += 10;
  }

  if (CAME_BACK_RE.test(text)) {
    const cameBackCount = readLocalEvents().filter(
      (e) =>
        e.name === RESURFACING_MODE_EVENTS.shown &&
        /\byou came back\b/i.test(e.meta?.preview ?? ""),
    ).length;
    penalty += 12 + Math.min(24, cameBackCount * 4);
  }

  if (/\b(this still felt unresolved|worth revisiting|appeared again)\b/i.test(text)) {
    penalty += 8;
  }

  return penalty;
}

export function applyReturnModeRankAdjustment(
  note: MemoryNote,
  entries: JournalEntry[],
  baseScore: number,
): number {
  return Math.max(0, baseScore - getReturnModeFatiguePenalty(note, entries));
}
