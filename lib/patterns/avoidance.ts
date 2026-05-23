import { addDaysToKey, toDayKey } from "@/lib/dates";
import { formatEntryDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

export type AvoidanceKind =
  | "vague_reference"
  | "unnamed_stressor"
  | "indirect_reference"
  | "emotional_hedging"
  | "topic_proximity";

export interface AvoidanceEvidence {
  entryId: string;
  dateKey: string;
  dateLabel: string;
  phrase: string;
  mood?: string;
}

export interface AvoidanceSignal {
  id: string;
  kind: AvoidanceKind;
  title: string;
  explanation: string;
  evidence: AvoidanceEvidence[];
  confidence: number;
  entryIds: string[];
  trigger?: string;
}

const VAGUE_PATTERNS: Array<{ re: RegExp; label: string }> = [
  { re: /\bstuff\b/gi, label: "stuff" },
  { re: /\bthings\b/gi, label: "things" },
  { re: /\beverything\b/gi, label: "everything" },
  { re: /\bthat situation\b/gi, label: "that situation" },
  { re: /\bthis stuff\b/gi, label: "this stuff" },
  { re: /\bsomething\b/gi, label: "something" },
  { re: /\bsomeone\b/gi, label: "someone" },
  { re: /\bwhatever\b/gi, label: "whatever" },
  { re: /\bthat thing\b/gi, label: "that thing" },
];

const HEDGING_PATTERNS: Array<{ re: RegExp; label: string }> = [
  { re: /\bmaybe\b/gi, label: "maybe" },
  { re: /\bsort of\b/gi, label: "sort of" },
  { re: /\bi guess\b/gi, label: "I guess" },
  { re: /\bprobably\b/gi, label: "probably" },
  { re: /\bkind of\b/gi, label: "kind of" },
  { re: /\bnot sure\b/gi, label: "not sure" },
  { re: /\bi don'?t know\b/gi, label: "I don't know" },
];

const INDIRECT_PATTERNS: Array<{ re: RegExp; label: string }> = [
  { re: /\bthat person\b/gi, label: "that person" },
  { re: /\bthe situation\b/gi, label: "the situation" },
  { re: /\bover there\b/gi, label: "over there" },
  { re: /\bthey said\b/gi, label: "they said" },
  { re: /\bwith them\b/gi, label: "with them" },
];

const STRESS_WITHOUT_NAME =
  /\b(stressed|anxious|worried|overwhelmed|tense|pressure|heavy|hard|drained|exhausted)\b/gi;

const NAMED_ENTITY =
  /\b[A-Z][a-z]{2,}\b|\bmy (mom|dad|mother|father|partner|boss|friend|team|manager|coworker|colleague|wife|husband|therapist|doctor)\b/i;

interface MutableSignal {
  id: string;
  kind: AvoidanceKind;
  title: string;
  explanation: string;
  evidence: AvoidanceEvidence[];
  entryIds: Set<string>;
  trigger?: string;
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function extractSnippet(text: string, index: number, length: number): string {
  const start = Math.max(0, index - 45);
  const end = Math.min(text.length, index + length + 45);
  let snippet = text.slice(start, end).trim();
  if (start > 0) snippet = `…${snippet}`;
  if (end < text.length) snippet = `${snippet}…`;
  return snippet.slice(0, 160);
}

function hasNamedEntity(text: string): boolean {
  return NAMED_ENTITY.test(text);
}

function evidenceFrom(
  entry: JournalEntry,
  matchText: string,
  index: number,
): AvoidanceEvidence {
  return {
    entryId: entry.id,
    dateKey: toDayKey(entry.createdAt),
    dateLabel: formatEntryDate(entry.createdAt),
    phrase: extractSnippet(entry.transcript, index, matchText.length),
    mood: entry.reflection.mood,
  };
}

function confidenceScore(entryCount: number, evidenceCount: number): number {
  return Math.min(100, entryCount * 22 + evidenceCount * 10 + (entryCount >= 2 ? 12 : 0));
}

function confidenceLabel(score: number): string {
  if (score >= 70) return "Strong pattern";
  if (score >= 50) return "Moderate pattern";
  return "Possible pattern";
}

function finalizeSignal(raw: MutableSignal): AvoidanceSignal {
  const entryIds = [...raw.entryIds];
  const confidence = confidenceScore(entryIds.length, raw.evidence.length);
  return {
    id: raw.id,
    kind: raw.kind,
    title: raw.title,
    explanation: raw.explanation,
    evidence: raw.evidence.slice(-6),
    confidence,
    entryIds,
    trigger: raw.trigger,
  };
}

function pushEvidence(
  store: Map<string, MutableSignal>,
  key: string,
  init: Omit<MutableSignal, "evidence" | "entryIds">,
  entry: JournalEntry,
  matchText: string,
  index: number,
): void {
  const record =
    store.get(key) ??
    ({
      ...init,
      evidence: [],
      entryIds: new Set<string>(),
    } satisfies MutableSignal);

  record.entryIds.add(entry.id);
  record.evidence.push(evidenceFrom(entry, matchText, index));
  store.set(key, record);
}

function scanPatterns(
  store: Map<string, MutableSignal>,
  entries: JournalEntry[],
  patterns: Array<{ re: RegExp; label: string }>,
  kind: AvoidanceKind,
  titleFor: (label: string, entryCount: number) => string,
  explanationFor: (label: string, entryCount: number, evidenceCount: number) => string,
): void {
  for (const { re, label } of patterns) {
    const key = `${kind}:${label.toLowerCase()}`;

    for (const entry of entries) {
      const text = entry.transcript;
      const regex = new RegExp(re.source, re.flags);
      let match: RegExpExecArray | null;

      while ((match = regex.exec(text)) !== null) {
        pushEvidence(
          store,
          key,
          {
            id: key,
            kind,
            title: titleFor(label, 0),
            explanation: explanationFor(label, 0, 0),
            trigger: label,
          },
          entry,
          match[0],
          match.index,
        );
      }
    }
  }

  for (const [key, record] of [...store.entries()]) {
    if (!key.startsWith(`${kind}:`)) continue;
    const label = record.trigger ?? key.split(":").slice(1).join(":");
    const entryCount = record.entryIds.size;
    const evidenceCount = record.evidence.length;

    if (entryCount < 2 && evidenceCount < 2) {
      store.delete(key);
      continue;
    }

    record.title = titleFor(label, entryCount);
    record.explanation = explanationFor(label, entryCount, evidenceCount);
  }
}

function detectVagueReferences(entries: JournalEntry[]): AvoidanceSignal[] {
  const store = new Map<string, MutableSignal>();

  scanPatterns(
    store,
    entries,
    VAGUE_PATTERNS,
    "vague_reference",
    (label, entryCount) =>
      entryCount >= 2
        ? `"${label}" appears without specifics across several reflections`
        : `"${label}" appears without naming what you mean`,
    (label, entryCount, evidenceCount) =>
      entryCount >= 2
        ? `This topic appears indirectly several times — "${label}" showed up in ${entryCount} reflections (${evidenceCount} uses) without naming the person, place, or detail directly. This is language pattern observation only, not a clinical claim.`
        : `"${label}" appears in your words without a clear referent — the subject stays off-record while you describe the feeling around it.`,
  );

  return [...store.values()].map(finalizeSignal);
}

function detectHedging(entries: JournalEntry[]): AvoidanceSignal[] {
  const store = new Map<string, MutableSignal>();
  const hedgeHits = new Map<string, AvoidanceEvidence[]>();

  for (const entry of entries) {
    const labels = new Set<string>();

    for (const { re, label } of HEDGING_PATTERNS) {
      const regex = new RegExp(re.source, re.flags);
      let match: RegExpExecArray | null;

      while ((match = regex.exec(entry.transcript)) !== null) {
        labels.add(label);
        const list = hedgeHits.get(label) ?? [];
        list.push(evidenceFrom(entry, match[0], match.index));
        hedgeHits.set(label, list);
      }
    }

    if (labels.size >= 2) {
      const key = `emotional_hedging:entry-${entry.id}`;
      store.set(key, {
        id: key,
        kind: "emotional_hedging",
        title: "Hedging language clusters in this reflection",
        explanation:
          "Several softening phrases appear together — you defer certainty while still circling the topic. This notes wording, not a judgment about what you should discuss.",
        evidence: [...labels].flatMap((l) => hedgeHits.get(l) ?? []).slice(0, 4),
        entryIds: new Set([entry.id]),
        trigger: [...labels].join(", "),
      });
    }
  }

  const crossEntryLabels = [...hedgeHits.entries()].filter(
    ([, ev]) => new Set(ev.map((e) => e.entryId)).size >= 2,
  );

  if (crossEntryLabels.length >= 2) {
    const labels = crossEntryLabels.map(([l]) => l);
    const evidence = crossEntryLabels.flatMap(([, ev]) => ev).slice(0, 6);
    const entryIds = new Set(evidence.map((e) => e.entryId));

    store.set("emotional_hedging:cross", {
      id: "emotional_hedging:cross",
      kind: "emotional_hedging",
      title: "Hedging language recurs across reflections",
      explanation: `Phrases like ${labels.slice(0, 4).join(", ")} appear in multiple entries — you soften or defer certainty while the subject stays partly indirect.`,
      evidence,
      entryIds,
      trigger: labels.join(", "),
    });
  }

  return [...store.values()]
    .filter((r) => r.evidence.length >= 2 || r.entryIds.size >= 2)
    .map(finalizeSignal);
}

function detectIndirectReferences(entries: JournalEntry[]): AvoidanceSignal[] {
  const store = new Map<string, MutableSignal>();

  scanPatterns(
    store,
    entries,
    INDIRECT_PATTERNS,
    "indirect_reference",
    (label, entryCount) =>
      entryCount >= 2
        ? `"${label}" recurs without naming who or what`
        : `Indirect reference: "${label}"`,
    (label, entryCount, evidenceCount) =>
      entryCount >= 2
        ? `This topic appears indirectly several times — "${label}" showed up in ${entryCount} reflections. The person or topic stays unnamed even while you describe the context around it.`
        : `"${label}" points to someone or something without naming them directly.`,
  );

  return [...store.values()].map(finalizeSignal);
}

function detectUnnamedStressors(entries: JournalEntry[]): AvoidanceSignal[] {
  const evidence: AvoidanceEvidence[] = [];
  const entryIds = new Set<string>();

  for (const entry of entries) {
    const text = entry.transcript;
    if (hasNamedEntity(text)) continue;

    const regex = new RegExp(STRESS_WITHOUT_NAME.source, STRESS_WITHOUT_NAME.flags);
    let match: RegExpExecArray | null;
    let hits = 0;

    while ((match = regex.exec(text)) !== null) {
      hits += 1;
      if (hits <= 2) {
        evidence.push(evidenceFrom(entry, match[0], match.index));
      }
    }

    if (hits >= 2) entryIds.add(entry.id);
  }

  if (entryIds.size < 2 && evidence.length < 3) return [];

  return [
    finalizeSignal({
      id: "unnamed_stressor:recurring",
      kind: "unnamed_stressor",
      title: "Stress language without a named source",
      explanation:
        entryIds.size >= 2
          ? `Pressure or tension language appears in ${entryIds.size} reflections without naming who, what, or where — the stressor stays implicit in your words. This is pattern observation only.`
          : "You describe pressure or tension more than once without naming the source — the stressor stays implicit in your words.",
      evidence,
      entryIds,
      trigger: "unnamed stress",
    }),
  ];
}

function findFirstVagueMatch(text: string): RegExpExecArray | null {
  for (const { re } of VAGUE_PATTERNS) {
    const regex = new RegExp(re.source, re.flags);
    const match = regex.exec(text);
    if (match) return match;
  }
  return null;
}

function detectTopicProximity(entries: JournalEntry[]): AvoidanceSignal[] {
  const themeEntries = new Map<string, { entry: JournalEntry; evidence: AvoidanceEvidence }[]>();

  for (const entry of entries) {
    const themes = entry.reflection.recurringThemes ?? [];
    if (themes.length === 0) continue;

    const text = entry.transcript.toLowerCase();
    const vagueMatch = findFirstVagueMatch(entry.transcript);
    if (!vagueMatch) continue;

    for (const theme of themes) {
      const themeLower = theme.toLowerCase();
      if (text.includes(themeLower)) continue;

      const list = themeEntries.get(themeLower) ?? [];
      list.push({
        entry,
        evidence: evidenceFrom(entry, vagueMatch[0], vagueMatch.index),
      });
      themeEntries.set(themeLower, list);
    }
  }

  const results: AvoidanceSignal[] = [];

  for (const [theme, rows] of themeEntries.entries()) {
    const uniqueEntries = new Set(rows.map((r) => r.entry.id));
    if (uniqueEntries.size < 2) continue;

    results.push(
      finalizeSignal({
        id: `topic_proximity:${theme}`,
        kind: "topic_proximity",
        title: `"${theme}" appears indirectly several times`,
        explanation: `A recurring theme ("${theme}") shows up in your reflections, but your words often circle it with vague phrasing instead of naming it directly — ${uniqueEntries.size} entries with this pattern.`,
        evidence: rows.map((r) => r.evidence).slice(0, 6),
        entryIds: uniqueEntries,
        trigger: theme,
      }),
    );
  }

  return results;
}

function dedupeSignals(signals: AvoidanceSignal[]): AvoidanceSignal[] {
  const seen = new Set<string>();
  return signals.filter((s) => {
    if (seen.has(s.id)) return false;
    seen.add(s.id);
    return true;
  });
}

/** Detect avoidance-related language patterns across the full archive. */
export function detectAllAvoidanceSignals(entries: JournalEntry[]): AvoidanceSignal[] {
  if (entries.length === 0) return [];

  const sorted = sortedEntries(entries);
  const combined = dedupeSignals([
    ...detectVagueReferences(sorted),
    ...detectIndirectReferences(sorted),
    ...detectHedging(sorted),
    ...detectUnnamedStressors(sorted),
    ...detectTopicProximity(sorted),
  ]);

  return combined
    .sort((a, b) => b.confidence - a.confidence || b.entryIds.length - a.entryIds.length)
    .slice(0, 12);
}

/** Signals involving a specific entry. */
export function detectAvoidanceForEntry(
  entries: JournalEntry[],
  entryId: string,
): AvoidanceSignal[] {
  return detectAllAvoidanceSignals(entries).filter((s) => s.entryIds.includes(entryId));
}

/** Signals with evidence in the last N days. */
export function detectRecentAvoidanceSignals(
  entries: JournalEntry[],
  days = 7,
): AvoidanceSignal[] {
  const cutoff = addDaysToKey(toDayKey(new Date().toISOString()), -(days - 1));
  return detectAllAvoidanceSignals(entries).filter((s) =>
    s.evidence.some((e) => e.dateKey >= cutoff),
  );
}

export { confidenceLabel };

/** Adapter for legacy pattern-insights shape. */
export function toLegacyAvoidanceSignal(signal: AvoidanceSignal): {
  id: string;
  label: string;
  detail: string;
  kind: "vague_reference" | "unnamed_stressor" | "indirect_reference" | "emotional_hedging";
} {
  return {
    id: signal.id,
    kind: signal.kind === "topic_proximity" ? "indirect_reference" : signal.kind,
    label: signal.title,
    detail: signal.explanation,
  };
}

/** Per-entry signals for InsightCard (includes single-entry hedging clusters). */
export function detectAvoidanceSignalsForEntry(
  entries: JournalEntry[],
  entryId: string,
): Array<{
  id: string;
  label: string;
  detail: string;
  kind: "vague_reference" | "unnamed_stressor" | "indirect_reference" | "emotional_hedging";
}> {
  return detectAvoidanceForEntry(entries, entryId)
    .map(toLegacyAvoidanceSignal)
    .slice(0, 5);
}
