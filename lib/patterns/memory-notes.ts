import { buildChangeReport } from "@/lib/patterns/changes";
import { buildContinuityMomentsReport } from "@/lib/patterns/continuity-moments";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import type { ChangeDetectionReport } from "@/types/changes";
import type { ContinuityCallbackKind, ContinuityMomentsReport, ThenVsNowComparison } from "@/types/continuity-moments";
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
  if (/returned|reappeared|pattern_returned/.test(kind)) return "returned";
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

export function buildMemoryNotesReport(
  entries: JournalEntry[],
  options: {
    context?: "entry" | "weekly" | "monthly" | "memory" | "timeline";
    entryId?: string;
    maxTotal?: number;
  } = {},
): MemoryNotesReport {
  const context = options.context ?? "memory";
  const maxTotal = options.maxTotal ?? 3;

  const continuity = buildContinuityMomentsReport(entries, {
    context,
    entryId: options.entryId,
    callbackLimit: maxTotal,
    landmarkLimit: 2,
  });

  const changes =
    context === "entry" && options.entryId
      ? buildChangeReport(entries, { scope: "archive", limit: 1 })
      : buildChangeReport(entries, {
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

  for (const lm of continuity.landmarks) {
    pushNote(
      all,
      noteFromText(lm.id, lm.text, "changed", lm.confidence, {
        entryId: lm.entryIds[0],
      }),
    );
  }

  for (const m of continuity.moments) {
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

  const seen = new Set<string>();
  const deduped = all
    .filter((n) => n.confidence >= USEFULNESS_MIN_CONFIDENCE)
    .sort((a, b) => b.confidence - a.confidence)
    .filter((n) => {
      const key = n.text.slice(0, 40);
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .slice(0, maxTotal);

  const changed = deduped.filter((n) => n.category === "changed");
  const faded = deduped.filter((n) => n.category === "faded");
  const returned = deduped.filter((n) => n.category === "returned");

  return {
    changed,
    faded,
    returned,
    all: deduped,
    hasData: deduped.length > 0,
  };
}

export function thenVsNowToNote(comparison: ThenVsNowComparison): MemoryNote | null {
  if (comparison.confidence < 65) return null;
  const text =
    comparison.headline.replace(/intensity|mood|pattern|signal/gi, "").trim() ||
    "This sounds different from before.";
  return noteFromText(`tvn-${comparison.then.entryId}`, text, "changed", comparison.confidence, {
    pastQuote: comparison.then.snippet,
    currentQuote: comparison.now.snippet,
    pastEntryId: comparison.then.entryId,
    entryId: comparison.now.entryId,
  });
}

export function entryMemoryNotes(
  entries: JournalEntry[],
  entryId: string,
): {
  callback: MemoryNote | null;
  thenVsNow: MemoryNote | null;
  whatChanged: MemoryNote | null;
} {
  const continuity = buildContinuityMomentsReport(entries, {
    context: "entry",
    entryId,
    callbackLimit: 1,
    landmarkLimit: 0,
  });

  const callback = continuity.callbacks[0]
    ? noteFromText(
        continuity.callbacks[0].id,
        continuity.callbacks[0].text,
        categoryForCallback(continuity.callbacks[0].kind),
        continuity.callbacks[0].confidence,
        { entryId },
      )
    : null;

  const thenVsNow = continuity.thenVsNow ? thenVsNowToNote(continuity.thenVsNow) : null;

  const changes = buildChangeReport(entries, { scope: "archive", limit: 3 });
  const top = changes.changes.find((c) => c.entryIds.includes(entryId));
  const whatChanged = top
    ? noteFromText(top.id, top.summary, "changed", top.confidence, {
        entryId,
        pastQuote: top.beforeEvidence[0]?.snippet,
        currentQuote: top.afterEvidence[0]?.snippet,
      })
    : null;

  return { callback, thenVsNow, whatChanged };
}

export type { ChangeDetectionReport, ContinuityMomentsReport };
