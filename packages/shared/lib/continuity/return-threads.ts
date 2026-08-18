import { detectThinkingOutLoudSignals } from "@/lib/clarity/thinking-out-loud-signals";
import {
  buildContinuityLineForThread,
  gapDaysBetween,
  quoteFromEntry,
} from "@/lib/continuity/build-continuity-lines";
import {
  gateContinuityLine,
  gateContinuityQuote,
} from "@/lib/continuity/continuity-quality-gate";
import { isPrimarySurfacedReflection } from "@/lib/reflection/reflection-quality-gate";
import { buildEntityMemoryFromEntries } from "@/lib/entity-memory";
import { getActiveOpenLoops } from "@/lib/open-loops/open-loop-storage";
import { detectAllContradictions } from "@/lib/patterns/contradictions";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import type {
  ReturnThread,
  ReturnThreadGroups,
  ReturnThreadType,
  ReturnThreadsReport,
} from "@/types/return-thread";
import type { JournalEntry } from "@/types/journal";

const MIN_PHRASE_ENTRIES = 2;
const MIN_PHRASE_COUNT = 2;
const MIN_ENTITY_MENTIONS = 2;
const MIN_CONFIDENCE = 52;

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function themeKey(entries: JournalEntry[]): string | null {
  const themes = entries.flatMap((e) => e.reflection.recurringThemes ?? []);
  if (themes.length === 0) return null;
  const counts = new Map<string, number>();
  for (const t of themes) {
    const k = t.trim().toLowerCase();
    if (!k) continue;
    counts.set(k, (counts.get(k) ?? 0) + 1);
  }
  let best: string | null = null;
  let max = 0;
  for (const [k, n] of counts) {
    if (n > max) {
      max = n;
      best = k;
    }
  }
  return best;
}

function pushThread(
  list: ReturnThread[],
  seen: Set<string>,
  draft: Omit<ReturnThread, "continuityLine"> & { continuityLine?: string },
): void {
  if (seen.has(draft.id)) return;
  const anchor = gateContinuityQuote(draft.anchorQuote) ?? "";
  const latest = gateContinuityQuote(draft.latestQuote) ?? "";
  if (!anchor.trim() && !latest.trim()) return;

  const continuityLine =
    draft.continuityLine ??
    buildContinuityLineForThread({
      type: draft.type,
      anchorQuote: anchor || draft.anchorQuote,
      latestQuote: latest || draft.latestQuote,
      gapDays: draft.gapDays,
      contextLabel: draft.contextLabel,
      appearances: draft.appearances,
    });

  const gatedLine = gateContinuityLine(continuityLine);
  if (!gatedLine) return;

  seen.add(draft.id);
  list.push({
    ...draft,
    anchorQuote: anchor || draft.anchorQuote,
    latestQuote: latest || draft.latestQuote,
    continuityLine: gatedLine,
  });
}

function threadsFromPhrases(entries: JournalEntry[], seen: Set<string>): ReturnThread[] {
  const out: ReturnThread[] = [];
  const phrases = buildPhraseMemory(entries);

  for (const record of phrases) {
    if (record.entryIds.length < MIN_PHRASE_ENTRIES || record.count < MIN_PHRASE_COUNT) {
      continue;
    }
    const sorted = record.occurrences.sort(
      (a, b) => new Date(a.dateKey).getTime() - new Date(b.dateKey).getTime(),
    );
    const first = sorted[0];
    const last = sorted[sorted.length - 1];
    const anchor =
      first?.snippet.replace(/^…/, "").replace(/…$/, "").trim() || record.phrase;
    const latest =
      last?.snippet.replace(/^…/, "").replace(/…$/, "").trim() || record.phrase;
    const gapDays = gapDaysBetween(record.firstSeen, record.lastSeen);

    pushThread(out, seen, {
      id: `phrase-${record.phrase.slice(0, 24)}-${record.entryIds[0]}`,
      type: "repeated_phrase",
      anchorQuote: anchor.slice(0, 140),
      latestQuote: latest.slice(0, 140),
      firstSeenAt: record.firstSeen,
      lastSeenAt: record.lastSeen,
      appearances: record.count,
      relatedEntryIds: [...record.entryIds],
      contextLabel: record.phrase,
      gapDays,
    });
  }
  return out;
}

function threadsFromPeople(entries: JournalEntry[], seen: Set<string>): ReturnThread[] {
  const out: ReturnThread[] = [];
  const snapshot = buildEntityMemoryFromEntries(entries);
  const people = snapshot.people.filter((p) => p.mentionCount >= MIN_ENTITY_MENTIONS);

  for (const person of people.slice(0, 8)) {
    const related = sortedEntries(
      entries.filter((e) => person.entryIds.includes(e.id)),
    );
    if (related.length < 2) continue;

    const anchor = quoteFromEntry(related[0]) || person.name;
    const latest = quoteFromEntry(related[related.length - 1]) || person.name;

    pushThread(out, seen, {
      id: `person-${person.id}`,
      type: "recurring_person",
      anchorQuote: anchor,
      latestQuote: latest,
      firstSeenAt: person.firstMentionedAt,
      lastSeenAt: person.lastMentionedAt,
      appearances: person.mentionCount,
      relatedEntryIds: person.entryIds.slice(0, 8),
      contextLabel: person.name,
      gapDays: gapDaysBetween(person.firstMentionedAt, person.lastMentionedAt),
    });
  }
  return out;
}

function threadsFromContradictions(entries: JournalEntry[], seen: Set<string>): ReturnThread[] {
  const out: ReturnThread[] = [];
  const contradictions = detectAllContradictions(entries);

  for (const c of contradictions) {
    if (c.confidence < MIN_CONFIDENCE || c.evidence.length < 2) continue;

    const ev0 = c.evidence[0];
    const ev1 = c.evidence[c.evidence.length - 1];
    const anchor = ev0.phrase.slice(0, 140);
    const latest = ev1.phrase.slice(0, 140);
    const firstSeenAt =
      entries.find((e) => e.id === ev0.entryId)?.createdAt ?? entries[0]?.createdAt;
    const lastSeenAt =
      entries.find((e) => e.id === ev1.entryId)?.createdAt ?? entries[entries.length - 1]?.createdAt;
    if (!firstSeenAt || !lastSeenAt) continue;

    let type: ReturnThreadType = "contradiction";
    if (c.kind === "failed_intention") type = "unresolved_problem";
    else if (c.kind === "emotional_reversal") type = "emotional_reversal";
    else if (c.kind === "conflicting_statement" || c.kind === "want_vs_keep_doing") {
      type = "changed_position";
    }

    pushThread(out, seen, {
      id: `contradiction-${c.id}`,
      type,
      anchorQuote: anchor,
      latestQuote: latest,
      firstSeenAt,
      lastSeenAt,
      appearances: c.entryIds.length,
      relatedEntryIds: c.entryIds,
      contextLabel: c.theme,
      gapDays: gapDaysBetween(firstSeenAt, lastSeenAt),
    });
  }
  return out;
}

function threadsFromOpenLoops(entries: JournalEntry[], seen: Set<string>): ReturnThread[] {
  const out: ReturnThread[] = [];
  const loops = getActiveOpenLoops().slice(0, 6);

  for (const loop of loops) {
    const entry = entries.find((e) => e.id === loop.sourceEntryId);
    const anchor =
      loop.strongestAnchorPhrase?.trim() ||
      loop.connectedMoments[0]?.quoteFragment?.trim() ||
      (entry ? quoteFromEntry(entry) : "");
    const latestMoment = loop.connectedMoments[loop.connectedMoments.length - 1];
    const latestEntryId = latestMoment?.entryId ?? loop.relatedEntryIds.at(-1);
    const latestEntry = latestEntryId
      ? entries.find((e) => e.id === latestEntryId)
      : entry;
    const latest =
      latestMoment?.quoteFragment?.trim() ||
      (latestEntry ? quoteFromEntry(latestEntry) : anchor);
    if (!anchor) continue;

    pushThread(out, seen, {
      id: `open-loop-${loop.openLoopId}`,
      type: "unresolved_problem",
      anchorQuote: anchor.slice(0, 140),
      latestQuote: (latest || anchor).slice(0, 140),
      firstSeenAt: loop.firstSeenAt,
      lastSeenAt: loop.lastMentionedAt,
      appearances: Math.max(1, loop.recurrenceCount),
      relatedEntryIds: loop.relatedEntryIds.length
        ? loop.relatedEntryIds
        : entry
          ? [entry.id]
          : [],
      gapDays: gapDaysBetween(loop.firstSeenAt, loop.lastMentionedAt),
    });
  }
  return out;
}

function threadsFromSilenceReturn(entries: JournalEntry[], seen: Set<string>): ReturnThread[] {
  const out: ReturnThread[] = [];
  const sorted = sortedEntries(entries);
  const byTheme = new Map<string, JournalEntry[]>();

  for (const entry of sorted) {
    for (const theme of entry.reflection.recurringThemes ?? []) {
      const key = theme.trim().toLowerCase();
      if (!key || key.length < 3) continue;
      const list = byTheme.get(key) ?? [];
      list.push(entry);
      byTheme.set(key, list);
    }
  }

  for (const [theme, themed] of byTheme) {
    if (themed.length < 2) continue;
    for (let i = 1; i < themed.length; i += 1) {
      const prev = themed[i - 1];
      const current = themed[i];
      const gap = gapDaysBetween(prev.createdAt, current.createdAt);
      if (gap < 7) continue;

      const anchor = quoteFromEntry(prev);
      const latest = quoteFromEntry(current);
      if (!anchor || !latest) continue;

      pushThread(out, seen, {
        id: `silence-${theme}-${current.id}`,
        type: "silence_then_return",
        anchorQuote: anchor,
        latestQuote: latest,
        firstSeenAt: prev.createdAt,
        lastSeenAt: current.createdAt,
        appearances: themed.length,
        relatedEntryIds: [prev.id, current.id],
        contextLabel: theme,
        gapDays: gap,
      });
      break;
    }
  }
  return out;
}

function threadsFromUncertainty(entries: JournalEntry[], seen: Set<string>): ReturnThread[] {
  const out: ReturnThread[] = [];
  const sorted = sortedEntries(entries);
  const uncertain = sorted.filter((e) => {
    const t = e.transcript?.trim();
    if (!t) return false;
    const signals = detectThinkingOutLoudSignals(t);
    return signals.uncertaintyLikely && signals.confidence >= 40;
  });

  if (uncertain.length < 2) return out;

  const first = uncertain[0];
  const last = uncertain[uncertain.length - 1];
  const anchor = quoteFromEntry(first);
  const latest = quoteFromEntry(last);
  if (!anchor) return out;

  pushThread(out, seen, {
    id: `uncertainty-${first.id}-${last.id}`,
    type: "recurring_uncertainty",
    anchorQuote: anchor,
    latestQuote: latest || anchor,
    firstSeenAt: first.createdAt,
    lastSeenAt: last.createdAt,
    appearances: uncertain.length,
    relatedEntryIds: uncertain.map((e) => e.id).slice(-6),
    contextLabel: themeKey(uncertain) ?? undefined,
    gapDays: gapDaysBetween(first.createdAt, last.createdAt),
  });

  return out;
}

export function groupReturnThreads(threads: ReturnThread[]): ReturnThreadGroups {
  const wordsReturned: ReturnThread[] = [];
  const stillUnresolved: ReturnThread[] = [];
  const earlierNow: ReturnThread[] = [];
  const cameBack: ReturnThread[] = [];
  const repeatedSituations: ReturnThread[] = [];
  const peopleAgain: ReturnThread[] = [];

  for (const thread of threads) {
    switch (thread.type) {
      case "repeated_phrase":
        wordsReturned.push(thread);
        break;
      case "unresolved_problem":
      case "recurring_uncertainty":
        stillUnresolved.push(thread);
        break;
      case "changed_position":
      case "contradiction":
      case "emotional_reversal":
        earlierNow.push(thread);
        break;
      case "silence_then_return":
        cameBack.push(thread);
        break;
      case "recurring_person":
        peopleAgain.push(thread);
        break;
      default:
        cameBack.push(thread);
    }
    if (
      thread.type === "repeated_phrase" ||
      thread.type === "silence_then_return" ||
      thread.type === "unresolved_problem"
    ) {
      repeatedSituations.push(thread);
    }
  }

  const cap = (list: ReturnThread[], n: number) => list.slice(0, n);

  return {
    wordsReturned: cap(wordsReturned, 6),
    stillUnresolved: cap(stillUnresolved, 5),
    earlierNow: cap(earlierNow, 5),
    cameBack: cap(cameBack, 5),
    repeatedSituations: cap(repeatedSituations, 6),
    peopleAgain: cap(peopleAgain, 5),
  };
}

/** Build return threads across the archive — human recognizability over clever scoring. */
export function buildReturnThreads(entries: JournalEntry[]): ReturnThreadsReport {
  const eligible = entries.filter(
    (e) => isPrimarySurfacedReflection(e) || Boolean(quoteFromEntry(e)),
  );
  if (eligible.length < 2) {
    return {
      threads: [],
      groups: groupReturnThreads([]),
      hasData: false,
    };
  }

  const seen = new Set<string>();
  const combined: ReturnThread[] = [
    ...threadsFromContradictions(eligible, seen),
    ...threadsFromOpenLoops(eligible, seen),
    ...threadsFromPhrases(eligible, seen),
    ...threadsFromPeople(eligible, seen),
    ...threadsFromSilenceReturn(eligible, seen),
    ...threadsFromUncertainty(eligible, seen),
  ];

  const threads = combined
    .sort((a, b) => {
      const gap = (b.gapDays ?? 0) - (a.gapDays ?? 0);
      if (gap !== 0) return gap;
      return b.appearances - a.appearances;
    })
    .slice(0, 24);

  return {
    threads,
    groups: groupReturnThreads(threads),
    hasData: threads.length > 0,
  };
}
