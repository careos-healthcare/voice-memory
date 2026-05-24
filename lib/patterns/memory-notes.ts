import { buildChangeReport } from "@/lib/patterns/changes";
import { buildContinuityMomentsReport } from "@/lib/patterns/continuity-moments";
import {
  pickStrongestByWeight,
  weightMemoryNote,
  weightThenVsNow,
} from "@/lib/memory/emotional-weight";
import {
  MAX_MEMORY_NOTES,
  MAX_LANDMARKS,
} from "@/lib/patterns/note-limits";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import {
  applyMemoryHierarchy,
  pickStrongestMemoryNote,
} from "@/lib/refinement/memory-hierarchy";
import { prioritizeMemoryNotesByRevisitWorth } from "@/lib/refinement/revisit-worth";
import type { ChangeDetectionReport } from "@/types/changes";
import type {
  ContinuityCallbackKind,
  ContinuityMomentsReport,
  ThenVsNowComparison,
} from "@/types/continuity-moments";
import type { MemoryNote, MemoryNoteCategory, MemoryNotesReport } from "@/types/memory-note";
import type { JournalEntry } from "@/types/journal";

const FADED_KINDS = new Set<ContinuityCallbackKind>(["topic_stopped", "used_to_be_vague"]);
const RETURNED_KINDS = new Set<ContinuityCallbackKind>(["came_up_differently"]);

function categoryForCallback(kind: ContinuityCallbackKind): MemoryNoteCategory {
  if (FADED_KINDS.has(kind)) return "faded";
  if (RETURNED_KINDS.has(kind)) return "returned";
  return "changed";
}

function categoryForChangeKind(kind: string): MemoryNoteCategory {
  if (/disappeared|faded|stopped|less_hedged|phrase_stopped|topic_less/.test(kind)) return "faded";
  if (/returned|reappeared|pattern_returned|loop/.test(kind)) return "returned";
  return "changed";
}

function noteFromText(
  id: string,
  text: string,
  category: MemoryNoteCategory,
  confidence: number,
  extras?: Partial<MemoryNote>,
): MemoryNote | null {
  if (!helpsOrient(text, confidence)) return null;
  return {
    id,
    text,
    category,
    confidence,
    ...extras,
  };
}

function pushNote(bucket: MemoryNote[], note: MemoryNote | null): void {
  if (note) bucket.push(note);
}

function dedupeNotes(notes: MemoryNote[], sorted: JournalEntry[]): MemoryNote[] {
  const seen = new Set<string>();
  return notes
    .filter((n) => n.confidence >= USEFULNESS_MIN_CONFIDENCE)
    .sort((a, b) => weightMemoryNote(b, sorted) - weightMemoryNote(a, sorted))
    .filter((n) => {
      const key = n.text.slice(0, 40);
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function splitByCategory(
  notes: MemoryNote[],
  sorted: JournalEntry[],
): Pick<MemoryNotesReport, "changed" | "faded" | "returned" | "all"> {
  const limited = pickStrongestByWeight(
    dedupeNotes(notes, sorted),
    (note) => weightMemoryNote(note, sorted),
    MAX_MEMORY_NOTES,
  );
  return {
    all: limited,
    changed: limited.filter((n) => n.category === "changed"),
    faded: limited.filter((n) => n.category === "faded"),
    returned: limited.filter((n) => n.category === "returned"),
  };
}

function landmarksToNotes(
  continuity: ContinuityMomentsReport,
  sorted: JournalEntry[],
): MemoryNote[] {
  return pickStrongestByWeight(
    dedupeNotes(
      continuity.landmarks
        .map((lm) =>
          noteFromText(lm.id, lm.text, "changed", lm.confidence, {
            entryId: lm.entryIds[0],
          }),
        )
        .filter((n): n is MemoryNote => n !== null),
      sorted,
    ),
    (note) => weightMemoryNote(note, sorted),
    MAX_LANDMARKS,
  );
}

export function thenVsNowToNote(
  comparison: ThenVsNowComparison,
  sorted: JournalEntry[],
): MemoryNote | null {
  if (comparison.confidence < 65) return null;
  const text = comparison.headline.trim() || "You sound different here.";
  if (weightThenVsNow(comparison, sorted) < 65) return null;
  return noteFromText(`tvn-${comparison.then.entryId}-${comparison.subject}`, text, "changed", comparison.confidence, {
    pastQuote: comparison.then.snippet,
    currentQuote: comparison.now.snippet,
    pastEntryId: comparison.then.entryId,
    entryId: comparison.now.entryId,
  });
}

export function buildMemoryNotesReport(
  entries: JournalEntry[],
  options: {
    context?: "entry" | "weekly" | "monthly" | "memory" | "timeline";
    entryId?: string;
    maxTotal?: number;
    includeLandmarks?: boolean;
  } = {},
): MemoryNotesReport {
  const context = options.context ?? "memory";
  const maxTotal = options.maxTotal ?? MAX_MEMORY_NOTES;
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );

  const continuity = buildContinuityMomentsReport(entries, {
    context,
    entryId: options.entryId,
    callbackLimit: maxTotal,
    landmarkLimit: MAX_LANDMARKS,
  });

  const changes = buildChangeReport(entries, {
    scope: context === "weekly" ? "weekly" : context === "monthly" ? "monthly" : "archive",
    limit: maxTotal,
  });

  const all: MemoryNote[] = [];

  for (const cb of continuity.callbacks) {
    pushNote(
      all,
      noteFromText(cb.id, cb.text, categoryForCallback(cb.kind), cb.confidence, {
        entryId: cb.entryIds[cb.entryIds.length - 1],
        pastEntryId: cb.entryIds.length > 1 ? cb.entryIds[0] : undefined,
      }),
    );
  }

  for (const m of continuity.moments) {
    if (continuity.landmarks.some((l) => l.id === m.id)) continue;
    const cat: MemoryNoteCategory =
      m.kind === "phrase_disappearance" || m.kind === "last_concern_appearance"
        ? "faded"
        : m.kind === "loop_returning"
          ? "returned"
          : "changed";
    pushNote(
      all,
      noteFromText(m.id, m.text, cat, m.confidence, {
        entryId: m.entryIds[m.entryIds.length - 1],
      }),
    );
  }

  for (const ch of changes.changes) {
    pushNote(
      all,
      noteFromText(ch.id, ch.summary, categoryForChangeKind(ch.kind), ch.confidence, {
        entryId: ch.entryIds[ch.entryIds.length - 1],
        pastEntryId: ch.beforeEvidence[0]?.entryId,
        pastQuote: ch.beforeEvidence[0]?.snippet,
        currentQuote: ch.afterEvidence[0]?.snippet,
      }),
    );
  }

  const split = splitByCategory(
    prioritizeMemoryNotesByRevisitWorth(
      applyMemoryHierarchy(all, sorted, maxTotal),
      sorted,
      maxTotal,
    ),
    sorted,
  );
  const landmarks =
    options.includeLandmarks !== false
      ? applyMemoryHierarchy(landmarksToNotes(continuity, sorted), sorted, MAX_LANDMARKS)
      : [];

  return {
    ...split,
    landmarks,
    hasData: split.all.length > 0 || landmarks.length > 0,
  };
}

export interface EntryMemoryNotesResult {
  primaryCallback: MemoryNote | null;
  secondaryCallback: MemoryNote | null;
  thenVsNow: MemoryNote[];
  whatChanged: MemoryNote | null;
}

export function entryMemoryNotes(
  entries: JournalEntry[],
  entryId: string,
): EntryMemoryNotesResult {
  const continuity = buildContinuityMomentsReport(entries, {
    context: "entry",
    entryId,
    callbackLimit: 2,
    landmarkLimit: 0,
  });

  const callbacks = applyMemoryHierarchy(
    continuity.callbacks
      .map((cb) =>
        noteFromText(cb.id, cb.text, categoryForCallback(cb.kind), cb.confidence, { entryId }),
      )
      .filter((n): n is MemoryNote => n !== null),
    entries,
    1,
  );

  const thenVsNow = prioritizeMemoryNotesByRevisitWorth(
    applyMemoryHierarchy(
      (continuity.thenVsNowList ?? [])
        .map((comparison) => thenVsNowToNote(comparison, entries))
        .filter((n): n is MemoryNote => n !== null),
      entries,
      1,
    ),
    entries,
    1,
  );

  const changes = buildChangeReport(entries, { scope: "archive", limit: 4 });
  const top = changes.changes.find((c) => c.entryIds.includes(entryId));
  const whatChangedCandidate = top
    ? noteFromText(top.id, top.summary, "changed", top.confidence, {
        entryId,
        pastQuote: top.beforeEvidence[0]?.snippet,
        currentQuote: top.afterEvidence[0]?.snippet,
      })
    : null;
  const whatChanged = whatChangedCandidate
    ? pickStrongestMemoryNote([whatChangedCandidate], entries)
    : null;

  return {
    primaryCallback: callbacks[0] ?? null,
    secondaryCallback: null,
    thenVsNow,
    whatChanged,
  };
}

export type { ChangeDetectionReport, ContinuityMomentsReport };
