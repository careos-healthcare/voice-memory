import { toDayKey } from "@/lib/dates";
import { buildEntityMemoryFromEntries } from "@/lib/entity-memory";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { KeyPiece, KeyPieceKind, KeyPiecesReport, RoundupPeriod } from "@/types/reflective-roundup";

const MAX_ITEMS = 5;

const RELATIONSHIP_DISPLAY: Record<string, string> = {
  mom: "Mum",
  mother: "Mum",
  mum: "Mum",
  dad: "Dad",
  father: "Dad",
  partner: "your partner",
  wife: "your wife",
  husband: "your husband",
  spouse: "your spouse",
  boss: "your boss",
  manager: "your manager",
  friend: "your friend",
  friends: "your friends",
  therapist: "your therapist",
  doctor: "your doctor",
  sister: "your sister",
  brother: "your brother",
  son: "your son",
  daughter: "your daughter",
  kids: "your kids",
  child: "your child",
  children: "your children",
  colleague: "your colleague",
  coworker: "your coworker",
  team: "your team",
  parent: "your parent",
  parents: "your parents",
};

const DECISION_RE =
  /\b(i decided|i've decided|i am going to|i'm going to|i chose|i will|we decided|we're going to)\s+([^.!?\n]{4,56})/gi;
const UNRESOLVED_Q_RE =
  /\b(whether to|should i|what if i|do i|can i|why do i|how do i)\s+([^.!?\n?]{4,56})/gi;
const WANTED_RE =
  /\b(i want(?:ed)?|i wanted|i need(?:ed)?|i'd like|i would like)\s+([^.!?\n]{4,56})/gi;

interface Candidate {
  text: string;
  entryId: string;
  kind: KeyPieceKind;
  weight: number;
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function entriesInRange(
  entries: JournalEntry[],
  startDayKey: string,
  endDayKey: string,
): JournalEntry[] {
  return sortedEntries(entries).filter((entry) => {
    const key = toDayKey(entry.createdAt);
    return key >= startDayKey && key <= endDayKey;
  });
}

function entryText(entry: JournalEntry): string {
  return [
    entry.transcript,
    entry.reflection.exactLanguagePattern,
    entry.reflection.concreteObservation,
    entry.reflection.repeatedSignal,
    entry.reflection.hiddenConcern,
    entry.reflection.tensionOrContradiction,
    entry.reflection.avoidedOrVagueArea,
    ...(entry.reflection.patternObservations ?? []),
  ]
    .filter(Boolean)
    .join("\n");
}

function displayPersonName(name: string): string {
  const trimmed = name.trim();
  const lower = trimmed.toLowerCase();
  if (lower.startsWith("my ")) {
    const rel = lower.slice(3);
    return RELATIONSHIP_DISPLAY[rel] ?? rel.charAt(0).toUpperCase() + rel.slice(1);
  }
  return trimmed;
}

function cleanFragment(raw: string): string {
  return raw.trim().replace(/\s+/g, " ").replace(/[.,;:!?]+$/, "").toLowerCase();
}

function detectNamedEntities(entries: JournalEntry[]): Candidate[] {
  const memory = buildEntityMemoryFromEntries(entries);
  const candidates: Candidate[] = [];

  for (const person of memory.people) {
    if (person.mentionCount < 2) continue;
    const label = displayPersonName(person.name);
    const times = person.mentionCount === 2 ? "twice" : `${person.mentionCount} times`;
    candidates.push({
      text: `You mentioned ${label} ${times}.`,
      entryId: person.sampleEntryIds[0] ?? person.entryIds[0],
      kind: "named_entity",
      weight: 74 + person.mentionCount,
    });
  }

  for (const entity of [...memory.topics, ...memory.concerns]) {
    if (entity.mentionCount < 2) continue;
    if (entity.type === "person") continue;
    const label = entity.name.toLowerCase();
    candidates.push({
      text: `You mentioned ${label} twice.`,
      entryId: entity.sampleEntryIds[0] ?? entity.entryIds[0],
      kind: "named_entity",
      weight: 68 + entity.mentionCount,
    });
  }

  return candidates;
}

function detectRepeatedConcern(entries: JournalEntry[]): Candidate[] {
  const candidates: Candidate[] = [];

  for (const entity of buildEntityMemoryFromEntries(entries).concerns) {
    if (entity.mentionCount < 2) continue;
    const phrase = cleanFragment(entity.name);
    candidates.push({
      text: `You kept returning to ${phrase}.`,
      entryId: entity.sampleEntryIds[0] ?? entity.entryIds[0],
      kind: "repeated_concern",
      weight: 70 + entity.mentionCount,
    });
  }

  const topTheme = new Map<string, { count: number; entryId: string }>();
  for (const entry of entries) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.trim().toLowerCase();
      if (!key) continue;
      const row = topTheme.get(key);
      if (row) {
        row.count += 1;
      } else {
        topTheme.set(key, { count: 1, entryId: entry.id });
      }
    }
  }

  for (const [theme, row] of topTheme) {
    if (row.count < 2) continue;
    candidates.push({
      text: `You kept returning to ${theme}.`,
      entryId: row.entryId,
      kind: "repeated_concern",
      weight: 62 + row.count,
    });
  }

  return candidates.sort((a, b) => b.weight - a.weight).slice(0, 2);
}

function scanEntryPattern(
  entries: JournalEntry[],
  pattern: RegExp,
  kind: KeyPieceKind,
  format: (fragment: string, entryId: string) => Candidate | null,
  baseWeight: number,
): Candidate[] {
  const candidates: Candidate[] = [];
  const seen = new Set<string>();

  for (const entry of entries) {
    const text = entryText(entry);
    const re = new RegExp(pattern.source, pattern.flags);
    for (const match of text.matchAll(re)) {
      const fragment = match[2] ?? match[1] ?? match[0];
      if (!fragment) continue;
      const key = cleanFragment(fragment);
      if (key.length < 4 || seen.has(key)) continue;
      seen.add(key);
      const candidate = format(key, entry.id);
      if (candidate) {
        candidates.push({ ...candidate, kind, weight: baseWeight });
      }
      break;
    }
  }

  return candidates;
}

function detectUnresolvedQuestions(entries: JournalEntry[]): Candidate[] {
  const questionCounts = new Map<string, { count: number; entryId: string; full: string }>();

  for (const entry of entries) {
    const text = entryText(entry);
    const re = new RegExp(UNRESOLVED_Q_RE.source, UNRESOLVED_Q_RE.flags);
    for (const match of text.matchAll(re)) {
      const stem = cleanFragment(`${match[1] ?? ""} ${match[2] ?? ""}`);
      if (stem.length < 8) continue;
      const row = questionCounts.get(stem);
      if (row) {
        row.count += 1;
      } else {
        questionCounts.set(stem, { count: 1, entryId: entry.id, full: stem });
      }
    }
  }

  const ranked = [...questionCounts.entries()].sort((a, b) => b[1].count - a[1].count);
  if (ranked.length === 0) return [];

  const [, top] = ranked[0];
  const formatted = top.full.endsWith("?") ? top.full : `${top.full}.`;
  return [
    {
      text: `You kept asking ${formatted}`,
      entryId: top.entryId,
      kind: "unresolved_question",
      weight: 76 + top.count * 3,
    },
  ];
}

function detectDecisions(entries: JournalEntry[]): Candidate[] {
  return scanEntryPattern(
    entries,
    DECISION_RE,
    "decision",
    (fragment, entryId) => ({
      text: `You mentioned deciding to ${fragment}.`,
      entryId,
      kind: "decision",
      weight: 0,
    }),
    64,
  );
}

function detectWantedThings(entries: JournalEntry[]): Candidate[] {
  const fromEntities = buildEntityMemoryFromEntries(entries).goals
    .filter((goal) => goal.mentionCount >= 1)
    .slice(0, 2)
    .map((goal) => ({
      text: `You said you wanted ${cleanFragment(goal.name)}.`,
      entryId: goal.sampleEntryIds[0] ?? goal.entryIds[0],
      kind: "wanted_thing" as const,
      weight: 72 + goal.mentionCount,
    }));

  if (fromEntities.length > 0) return fromEntities;

  return scanEntryPattern(
    entries,
    WANTED_RE,
    "wanted_thing",
    (fragment, entryId) => ({
      text: `You said you wanted ${fragment}.`,
      entryId,
      kind: "wanted_thing",
      weight: 0,
    }),
    68,
  );
}

function detectRepeatedPhrases(entries: JournalEntry[]): Candidate[] {
  const phrases = buildPhraseMemory(entries)
    .filter((row) => row.count >= 2)
    .sort((a, b) => b.count - a.count);

  if (phrases.length === 0) return [];

  const top = phrases[0];
  const label = top.phrase.replace(/^"/, "").replace(/"$/, "");
  return [
    {
      text: `You kept saying "${label}."`,
      entryId: top.entryIds[top.entryIds.length - 1] ?? top.occurrences[0]?.entryId,
      kind: "phrase_repeated",
      weight: 66 + top.count,
    },
  ];
}

function detectAvoidedNaming(entries: JournalEntry[]): Candidate[] {
  for (const entry of [...entries].reverse()) {
    const avoided = entry.reflection.avoidedOrVagueArea?.trim();
    if (!avoided) continue;
    return [
      {
        text: "This stayed unnamed.",
        entryId: entry.id,
        kind: "avoided_naming",
        weight: 73,
      },
    ];
  }

  for (const entry of [...entries].reverse()) {
    const text = entryText(entry);
    if (/\b(that thing|something about|not ready to name|hard to name|won't name)\b/i.test(text)) {
      return [
        {
          text: "This stayed unnamed.",
          entryId: entry.id,
          kind: "avoided_naming",
          weight: 65,
        },
      ];
    }
  }

  return [];
}

function detectWorthRevisiting(entries: JournalEntry[], period: RoundupPeriod): Candidate[] {
  const revisitIds = new Set(
    readRetentionLoopEvents()
      .filter((event) => {
        const key = toDayKey(event.at);
        return key >= period.startDayKey && key <= period.endDayKey;
      })
      .flatMap((event) =>
        [event.targetEntryId, event.pastEntryId, event.entryId].filter(Boolean),
      ) as string[],
  );

  if (revisitIds.size > 0) {
    const entryId = [...revisitIds][0];
    return [
      {
        text: "This may be worth returning to.",
        entryId,
        kind: "worth_revisiting",
        weight: 71,
      },
    ];
  }

  const ranked = [...entries].sort((a, b) => {
    const score = (entry: JournalEntry) =>
      entry.reflection.emotionalIntensity +
      (entry.reflection.tensionOrContradiction?.trim() ? 2 : 0) +
      (entry.reflection.avoidedOrVagueArea?.trim() ? 1.5 : 0);
    return score(b) - score(a);
  });

  const top = ranked[0];
  if (!top) return [];
  if (
    top.reflection.emotionalIntensity < 6 &&
    !top.reflection.tensionOrContradiction?.trim() &&
    !top.reflection.avoidedOrVagueArea?.trim()
  ) {
    return [];
  }

  return [
    {
      text: "This may be worth returning to.",
      entryId: top.id,
      kind: "worth_revisiting",
      weight: 60 + top.reflection.emotionalIntensity,
    },
  ];
}

function pickItems(candidates: Candidate[]): KeyPiece[] {
  const usedKinds = new Set<KeyPieceKind>();
  const usedEntries = new Set<string>();
  const sorted = [...candidates].sort((a, b) => b.weight - a.weight);
  const picked: KeyPiece[] = [];

  for (const candidate of sorted) {
    if (picked.length >= MAX_ITEMS) break;
    if (usedKinds.has(candidate.kind)) continue;
    if (usedEntries.has(candidate.entryId) && picked.length >= 3) continue;

    usedKinds.add(candidate.kind);
    usedEntries.add(candidate.entryId);
    picked.push({
      id: `key-${candidate.kind}-${picked.length}`,
      text: candidate.text,
      entryId: candidate.entryId,
      kind: candidate.kind,
    });
  }

  return picked;
}

/** Quiet key-information extraction for a roundup period — no scores in UI. */
export function buildKeyPieces(
  period: RoundupPeriod,
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): KeyPiecesReport {
  const scoped = entriesInRange(entries, period.startDayKey, period.endDayKey);

  if (scoped.length === 0) {
    return { items: [], hasData: false };
  }

  const candidates: Candidate[] = [
    ...detectNamedEntities(scoped),
    ...detectRepeatedConcern(scoped),
    ...detectUnresolvedQuestions(scoped),
    ...detectWantedThings(scoped),
    ...detectRepeatedPhrases(scoped),
    ...detectDecisions(scoped),
    ...detectAvoidedNaming(scoped),
    ...detectWorthRevisiting(scoped, period),
  ];

  const items = pickItems(candidates);
  return {
    items,
    hasData: items.length > 0,
  };
}
