import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import {
  buildEntityMemoryFromEntries,
  type TrackedEntity,
} from "@/lib/entity-memory";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import type {
  RelationshipContinuityContext,
  RelationshipContinuityCopyExample,
  RelationshipContinuityKind,
  RelationshipContinuityNote,
  RelationshipContinuityReport,
} from "@/types/relationship-continuity";
import type { JournalEntry } from "@/types/journal";

const MIN_ENTRIES = 3;
const MIN_ENTITY_MENTIONS = 2;
const QUIET_DAYS = 14;
const STRONG_MIN = 62;

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|eventually|vague)\b/gi;
const DIRECT_RE =
  /\b(i will|decided|named|wrote down|clearly|for sure|definitely|told|said to)\b/gi;
const TENSION_RE =
  /\b(worried|anxious|tense|frustrated|upset|angry|hard|difficult|stress)\b/gi;

export interface RelationshipContinuityOptions {
  context: RelationshipContinuityContext;
  entryId?: string;
  limit?: number;
}

export const RELATIONSHIP_CONTINUITY_COPY_EXAMPLES: RelationshipContinuityCopyExample[] =
  [
    {
      kind: "language_calmer",
      message: "Sarah appears with less tension now.",
      whenShown: "A recurring person shows up with lower intensity or softer language than earlier mentions",
    },
    {
      kind: "first_named",
      message: "You named Mum directly here.",
      whenShown: "The first time you used a direct name instead of only a relationship phrase",
    },
    {
      kind: "person_quiet",
      message: "This person has been quiet for a while.",
      whenShown: "Someone who appeared more than once has not come up in recent reflections",
    },
    {
      kind: "language_more_direct",
      message: "Sarah appears with more direct language now.",
      whenShown: "Language around a recurring person became clearer or less hedged over time",
    },
    {
      kind: "appeared_more",
      message: "You mentioned Sarah more often lately.",
      whenShown: "Mentions of a person increased in the second half of your archive",
    },
    {
      kind: "appeared_less",
      message: "Sarah appears less often lately.",
      whenShown: "Mentions of a person decreased in the second half of your archive",
    },
    {
      kind: "topic_around_changed",
      message: "What comes up around Sarah has shifted.",
      whenShown: "Recurring themes linked to a person changed between earlier and later reflections",
    },
  ];

const CONTEXT_KIND_PRIORITY: Record<
  RelationshipContinuityContext,
  RelationshipContinuityKind[]
> = {
  memory: [
    "language_calmer",
    "person_quiet",
    "topic_around_changed",
    "language_more_direct",
    "appeared_more",
    "appeared_less",
    "first_named",
  ],
  threads: [
    "language_calmer",
    "topic_around_changed",
    "person_quiet",
    "language_more_direct",
    "first_named",
  ],
  entry: [
    "first_named",
    "language_calmer",
    "language_more_direct",
    "topic_around_changed",
    "person_quiet",
  ],
};

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function entityEntries(
  entity: TrackedEntity,
  allSorted: JournalEntry[],
): JournalEntry[] {
  const set = new Set(entity.entryIds);
  return allSorted.filter((entry) => set.has(entry.id));
}

function displayPersonName(entity: TrackedEntity): string {
  const lower = entity.name.toLowerCase();
  if (lower === "my mom" || lower === "my mother") return "Mum";
  if (lower === "my dad" || lower === "my father") return "Dad";
  if (lower.startsWith("my ")) {
    return entity.name.slice(3).charAt(0).toUpperCase() + entity.name.slice(4);
  }
  return entity.name;
}

function directNameLabel(entity: TrackedEntity): string | null {
  const lower = entity.name.toLowerCase();
  if (lower === "my mom" || lower === "my mother") return "Mum";
  if (lower === "my dad" || lower === "my father") return "Dad";
  if (lower.startsWith("my ")) return null;
  if (entity.type === "person") return entity.name;
  return null;
}

function hasDirectName(text: string, label: string): boolean {
  return new RegExp(`\\b${label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`, "i").test(
    text,
  );
}

function themesForEntries(entries: JournalEntry[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const entry of entries) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.trim().toLowerCase();
      if (key.length < 3) continue;
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
  }
  return counts;
}

function topTheme(counts: Map<string, number>): string | null {
  let top: { key: string; count: number } | null = null;
  for (const [key, count] of counts) {
    if (!top || count > top.count) top = { key, count };
  }
  return top?.key ?? null;
}

function isContinuityEntity(entity: TrackedEntity): boolean {
  return ["person", "place", "company"].includes(entity.type);
}

function pushNote(
  bucket: RelationshipContinuityNote[],
  note: RelationshipContinuityNote,
): void {
  if (note.strength < USEFULNESS_MIN_CONFIDENCE) return;
  const orienting = note.kind === "first_named" || helpsOrient(note.text, note.strength);
  if (!orienting) return;
  bucket.push(note);
}

function detectLanguageShift(
  entity: TrackedEntity,
  mentions: JournalEntry[],
): RelationshipContinuityNote[] {
  if (mentions.length < MIN_ENTITY_MENTIONS) return [];

  const mid = Math.floor(mentions.length / 2);
  const early = mentions.slice(0, Math.max(1, mid));
  const late = mentions.slice(Math.max(1, mid));
  if (late.length === 0) return [];

  const name = displayPersonName(entity);
  const notes: RelationshipContinuityNote[] = [];

  const earlyIntensity = roundAvg(early.map((e) => e.reflection.emotionalIntensity));
  const lateIntensity = roundAvg(late.map((e) => e.reflection.emotionalIntensity));
  const earlyHedge = roundAvg(early.map((e) => countMatches(e.transcript, HEDGE_RE)));
  const lateHedge = roundAvg(late.map((e) => countMatches(e.transcript, HEDGE_RE)));
  const earlyTension = roundAvg(early.map((e) => countMatches(e.transcript, TENSION_RE)));
  const lateTension = roundAvg(late.map((e) => countMatches(e.transcript, TENSION_RE)));
  const earlyDirect = roundAvg(early.map((e) => countMatches(e.transcript, DIRECT_RE)));
  const lateDirect = roundAvg(late.map((e) => countMatches(e.transcript, DIRECT_RE)));

  const calmer =
    lateIntensity <= earlyIntensity - 1 ||
    lateTension <= earlyTension - 0.8 ||
    (lateHedge <= earlyHedge - 0.8 && lateIntensity <= earlyIntensity);

  if (calmer) {
    pushNote(notes, {
      id: `rel-calmer-${entity.id}`,
      kind: "language_calmer",
      text: `${name} appears with less tension now.`,
      entityName: name,
      strength: STRONG_MIN + 4 + Math.max(0, earlyIntensity - lateIntensity),
      entryId: late[late.length - 1].id,
      pastEntryId: early[early.length - 1].id,
      href: `/entry/${late[late.length - 1].id}`,
    });
  }

  const moreDirect =
    lateDirect >= earlyDirect + 0.8 && lateHedge <= earlyHedge;

  if (moreDirect && !calmer) {
    pushNote(notes, {
      id: `rel-direct-${entity.id}`,
      kind: "language_more_direct",
      text: `${name} appears with more direct language now.`,
      entityName: name,
      strength: STRONG_MIN + 3,
      entryId: late[late.length - 1].id,
      pastEntryId: early[early.length - 1].id,
      href: `/entry/${late[late.length - 1].id}`,
    });
  }

  return notes;
}

function detectFrequencyShift(
  entity: TrackedEntity,
  allSorted: JournalEntry[],
  mentions: JournalEntry[],
): RelationshipContinuityNote[] {
  if (allSorted.length < MIN_ENTRIES || mentions.length < MIN_ENTITY_MENTIONS) {
    return [];
  }

  const mid = Math.floor(allSorted.length / 2);
  const earlyArchive = allSorted.slice(0, Math.max(1, mid));
  const lateArchive = allSorted.slice(Math.max(1, mid));
  const earlySet = new Set(earlyArchive.map((e) => e.id));
  const lateSet = new Set(lateArchive.map((e) => e.id));

  const earlyCount = mentions.filter((e) => earlySet.has(e.id)).length;
  const lateCount = mentions.filter((e) => lateSet.has(e.id)).length;
  const name = displayPersonName(entity);
  const notes: RelationshipContinuityNote[] = [];

  if (lateCount >= earlyCount + 2 && lateCount >= 2) {
    pushNote(notes, {
      id: `rel-more-${entity.id}`,
      kind: "appeared_more",
      text: `You mentioned ${name} more often lately.`,
      entityName: name,
      strength: STRONG_MIN + lateCount - earlyCount,
      entryId: mentions[mentions.length - 1].id,
      href: `/entry/${mentions[mentions.length - 1].id}`,
    });
  }

  if (earlyCount >= lateCount + 2 && earlyCount >= 2) {
    pushNote(notes, {
      id: `rel-less-${entity.id}`,
      kind: "appeared_less",
      text: `${name} appears less often lately.`,
      entityName: name,
      strength: STRONG_MIN + earlyCount - lateCount,
      entryId: mentions[mentions.length - 1].id,
      href: `/entry/${mentions[mentions.length - 1].id}`,
    });
  }

  return notes;
}

function detectPersonQuiet(
  entity: TrackedEntity,
  allSorted: JournalEntry[],
): RelationshipContinuityNote | null {
  if (entity.mentionCount < MIN_ENTITY_MENTIONS) return null;
  if (entity.type !== "person") return null;

  const latestEntry = allSorted[allSorted.length - 1];
  const gap = daysBetweenKeys(
    toDayKey(entity.lastMentionedAt),
    toDayKey(latestEntry.createdAt),
  );
  if (gap < QUIET_DAYS) return null;
  if (entity.entryIds.includes(latestEntry.id)) return null;

  const label =
    entity.name.toLowerCase().startsWith("my ") || entity.type === "person"
      ? "This person has been quiet for a while."
      : `${displayPersonName(entity)} has been quiet for a while.`;

  return {
    id: `rel-quiet-${entity.id}`,
    kind: "person_quiet",
    text: label,
    entityName: displayPersonName(entity),
    strength: STRONG_MIN + Math.min(8, Math.floor(gap / 3)),
    entryId: entity.entryIds[entity.entryIds.length - 1],
    href: `/entry/${entity.entryIds[entity.entryIds.length - 1]}`,
  };
}

function detectFirstNamed(
  entity: TrackedEntity,
  mentions: JournalEntry[],
): RelationshipContinuityNote | null {
  if (entity.type !== "person") return null;

  const directLabel = directNameLabel(entity);
  if (!directLabel) return null;

  for (const entry of mentions) {
    const text = entry.transcript;
    if (!hasDirectName(text, directLabel)) continue;

    const prior = mentions.filter((e) => e.id !== entry.id);
    const hadDirectBefore = prior.some((e) => hasDirectName(e.transcript, directLabel));
    if (hadDirectBefore) return null;

    const copy =
      directLabel === "Mum" || directLabel === "Dad"
        ? `You named ${directLabel} directly here.`
        : `You named ${directLabel} directly here.`;

    return {
      id: `rel-first-${entity.id}-${entry.id}`,
      kind: "first_named",
      text: copy,
      entityName: directLabel,
      strength: 68,
      entryId: entry.id,
      href: `/entry/${entry.id}`,
    };
  }

  return null;
}

function detectTopicAroundChanged(
  entity: TrackedEntity,
  mentions: JournalEntry[],
): RelationshipContinuityNote | null {
  if (mentions.length < MIN_ENTITY_MENTIONS + 1) return null;

  const mid = Math.floor(mentions.length / 2);
  const early = mentions.slice(0, Math.max(1, mid));
  const late = mentions.slice(Math.max(1, mid));

  const earlyTheme = topTheme(themesForEntries(early));
  const lateTheme = topTheme(themesForEntries(late));
  if (!earlyTheme || !lateTheme || earlyTheme === lateTheme) return null;

  const name = displayPersonName(entity);
  return {
    id: `rel-topic-${entity.id}`,
    kind: "topic_around_changed",
    text: `What comes up around ${name} has shifted.`,
    entityName: name,
    strength: STRONG_MIN + 5,
    entryId: late[late.length - 1].id,
    pastEntryId: early[early.length - 1].id,
    href: `/entry/${late[late.length - 1].id}`,
  };
}

function detectForEntity(
  entity: TrackedEntity,
  allSorted: JournalEntry[],
): RelationshipContinuityNote[] {
  const mentions = entityEntries(entity, allSorted);
  return [
    ...detectLanguageShift(entity, mentions),
    ...detectFrequencyShift(entity, allSorted, mentions),
    detectPersonQuiet(entity, allSorted),
    detectFirstNamed(entity, mentions),
    detectTopicAroundChanged(entity, mentions),
  ].filter((note): note is RelationshipContinuityNote => note !== null);
}

function dedupeNotes(notes: RelationshipContinuityNote[]): RelationshipContinuityNote[] {
  const seen = new Set<string>();
  return notes
    .sort((a, b) => b.strength - a.strength)
    .filter((note) => {
      const key = `${note.entityName}:${note.kind}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function pickForContext(
  notes: RelationshipContinuityNote[],
  context: RelationshipContinuityContext,
  limit: number,
): RelationshipContinuityNote[] {
  const sorted = dedupeNotes(notes).filter((note) => note.strength >= STRONG_MIN);
  const priority = CONTEXT_KIND_PRIORITY[context];
  const picked: RelationshipContinuityNote[] = [];
  const usedEntities = new Set<string>();

  for (const kind of priority) {
    const match = sorted.find(
      (note) => note.kind === kind && !usedEntities.has(note.entityName),
    );
    if (match) {
      picked.push(match);
      usedEntities.add(match.entityName);
    }
    if (picked.length >= limit) break;
  }

  if (picked.length < limit) {
    for (const note of sorted) {
      if (picked.length >= limit) break;
      if (picked.some((p) => p.id === note.id)) continue;
      if (usedEntities.has(note.entityName) && picked.some((p) => p.entityName === note.entityName)) {
        continue;
      }
      picked.push(note);
      usedEntities.add(note.entityName);
    }
  }

  return picked.slice(0, limit);
}

function filterForEntry(
  notes: RelationshipContinuityNote[],
  entryId: string,
  allSorted: JournalEntry[],
): RelationshipContinuityNote[] {
  const snapshot = buildEntityMemoryFromEntries(allSorted);
  const entities = [
    ...snapshot.people,
    ...snapshot.topics.filter((e) => e.type === "place" || e.type === "company"),
  ];
  const mentionedEntityNames = new Set<string>();

  for (const entity of entities) {
    if (!isContinuityEntity(entity)) continue;
    if (entity.entryIds.includes(entryId)) {
      mentionedEntityNames.add(displayPersonName(entity));
      mentionedEntityNames.add(entity.name);
    }
  }

  return notes.filter((note) => {
    if (note.entryId === entryId || note.pastEntryId === entryId) return true;
    return mentionedEntityNames.has(note.entityName);
  });
}

/** Detect how recurring people and entities appear differently over time. */
export function buildRelationshipContinuityReport(
  entries: JournalEntry[],
  options: RelationshipContinuityOptions,
): RelationshipContinuityReport {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ENTRIES) {
    return { notes: [], hasData: false };
  }

  const snapshot = buildEntityMemoryFromEntries(sorted);
  const entities = [
    ...snapshot.people,
    ...snapshot.topics.filter((e) => e.type === "place" || e.type === "company"),
  ].filter(isContinuityEntity);

  const candidates = entities.flatMap((entity) => detectForEntity(entity, sorted));
  let notes = pickForContext(candidates, options.context, options.limit ?? 4);

  if (options.context === "entry" && options.entryId) {
    notes = filterForEntry(candidates, options.entryId, sorted);
    notes = pickForContext(notes, "entry", options.limit ?? 2);
  }

  return { notes, hasData: notes.length > 0 };
}

export function memoryRelationshipNotes(
  entries: JournalEntry[],
  limit = 4,
): RelationshipContinuityNote[] {
  return buildRelationshipContinuityReport(entries, { context: "memory", limit }).notes;
}

export function threadsRelationshipNotes(
  entries: JournalEntry[],
  limit = 3,
): RelationshipContinuityNote[] {
  return buildRelationshipContinuityReport(entries, { context: "threads", limit }).notes;
}

export function entryRelationshipNotes(
  entries: JournalEntry[],
  entryId: string,
  limit = 2,
): RelationshipContinuityNote[] {
  return buildRelationshipContinuityReport(entries, {
    context: "entry",
    entryId,
    limit,
  }).notes;
}
