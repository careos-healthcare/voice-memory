import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildEntityMemoryFromEntries } from "@/lib/entity-memory";
import { formatEntryDate, formatRelativeDate } from "@/lib/utils";
import type {
  ConversationThread,
  ConversationThreadEntry,
  ConversationThreadEvolution,
  ConversationThreadReport,
  ConversationThreadSource,
} from "@/types/conversation-thread";
import type { JournalEntry } from "@/types/journal";

const MIN_THREAD_ENTRIES = 2;
const MIN_ARCHIVE_ENTRIES = 12;
const GAP_DAYS = 10;
const MAX_RELATED_ENTRIES = 8;

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|eventually|vague)\b/gi;
const DIRECT_RE =
  /\b(i will|decided|named|wrote down|clearly|for sure|definitely)\b/gi;

interface RawThread {
  title: string;
  source: ConversationThreadSource;
  entries: JournalEntry[];
  priority: number;
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function snippet(entry: JournalEntry): string {
  const fromReflection =
    entry.reflection.exactLanguagePattern?.trim() ||
    entry.reflection.concreteObservation?.trim();
  if (fromReflection) return fromReflection.slice(0, 160);
  return entry.transcript.trim().slice(0, 160);
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function textKey(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 72);
}

function toSlug(title: string): string {
  const base = title
    .toLowerCase()
    .replace(/[^\w\s-]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 56);
  return base || "thread";
}

function formatShortDate(iso: string): string {
  const [y, m, d] = toDayKey(iso).split("-").map(Number);
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: y !== new Date().getFullYear() ? "numeric" : undefined,
  }).format(new Date(y, m - 1, d));
}

function addEntryToMap(
  map: Map<string, RawThread>,
  key: string,
  title: string,
  source: ConversationThreadSource,
  entry: JournalEntry,
  priority: number,
): void {
  let row = map.get(key);
  if (!row) {
    row = { title, source, entries: [], priority };
    map.set(key, row);
  }
  if (!row.entries.some((e) => e.id === entry.id)) {
    row.entries.push(entry);
  }
  row.priority = Math.max(row.priority, priority);
}

function buildThemeThreads(sorted: JournalEntry[]): RawThread[] {
  const map = new Map<string, RawThread>();

  for (const entry of sorted) {
    for (const theme of entry.reflection.recurringThemes) {
      const trimmed = theme.trim();
      if (trimmed.length < 3) continue;
      const key = `theme:${trimmed.toLowerCase()}`;
      addEntryToMap(map, key, trimmed, "theme", entry, 70);
    }
  }

  return [...map.values()].filter((row) => row.entries.length >= MIN_THREAD_ENTRIES);
}

function buildEntityThreads(sorted: JournalEntry[]): RawThread[] {
  const snapshot = buildEntityMemoryFromEntries(sorted);
  const raw: RawThread[] = [];

  for (const person of snapshot.people) {
    if (person.entryIds.length < MIN_THREAD_ENTRIES) continue;
    const entries = sorted.filter((e) => person.entryIds.includes(e.id));
    raw.push({
      title: person.name,
      source: "person",
      entries,
      priority: 68 + person.mentionCount,
    });
  }

  for (const topic of snapshot.topics) {
    if (topic.entryIds.length < MIN_THREAD_ENTRIES) continue;
    const entries = sorted.filter((e) => topic.entryIds.includes(e.id));
    raw.push({
      title: topic.name,
      source: topic.type === "topic" ? "topic" : "topic",
      entries,
      priority: 66 + topic.mentionCount,
    });
  }

  return raw;
}

function buildPhraseThreads(sorted: JournalEntry[]): RawThread[] {
  const map = new Map<string, RawThread>();

  for (const entry of sorted) {
    const phrase = entry.reflection.exactLanguagePattern?.trim();
    if (!phrase || phrase.length < 8) continue;
    const key = `phrase:${textKey(phrase)}`;
    const label =
      phrase.length > 48 ? `${phrase.slice(0, 45).trim()}…` : phrase;
    addEntryToMap(map, key, label, "phrase", entry, 64);
  }

  for (const entry of sorted) {
    const transcript = entry.transcript.trim();
    if (transcript.length < 24) continue;

    const words = transcript.toLowerCase().split(/\s+/);
    for (let len = 3; len <= 5; len += 1) {
      for (let i = 0; i <= words.length - len; i += 1) {
        const chunk = words.slice(i, i + len).join(" ");
        if (chunk.length < 10) continue;
        if (/^(i am|i have|i was|and the|but i|that i)\b/.test(chunk)) continue;
        const key = `phrase:${chunk}`;
        const existing = map.get(key);
        if (existing && !existing.entries.some((e) => e.id === entry.id)) {
          existing.entries.push(entry);
        } else if (!existing) {
          map.set(key, {
            title: chunk.charAt(0).toUpperCase() + chunk.slice(1),
            source: "phrase",
            entries: [entry],
            priority: 62,
          });
        }
      }
    }
  }

  return [...map.values()].filter((row) => row.entries.length >= MIN_THREAD_ENTRIES);
}

function entryOverlap(a: JournalEntry[], b: JournalEntry[]): number {
  const setB = new Set(b.map((e) => e.id));
  const shared = a.filter((e) => setB.has(e.id)).length;
  return shared / Math.min(a.length, b.length);
}

function dedupeRawThreads(raw: RawThread[]): RawThread[] {
  const sorted = [...raw].sort((a, b) => {
    if (b.entries.length !== a.entries.length) {
      return b.entries.length - a.entries.length;
    }
    return b.priority - a.priority;
  });

  const kept: RawThread[] = [];

  for (const candidate of sorted) {
    const duplicate = kept.find((existing) => {
      if (existing.title.toLowerCase() === candidate.title.toLowerCase()) {
        return true;
      }
      if (existing.source === candidate.source) {
        return entryOverlap(existing.entries, candidate.entries) >= 0.75;
      }
      return entryOverlap(existing.entries, candidate.entries) >= 0.9;
    });

    if (duplicate) {
      for (const entry of candidate.entries) {
        if (!duplicate.entries.some((e) => e.id === entry.id)) {
          duplicate.entries.push(entry);
        }
      }
      duplicate.priority = Math.max(duplicate.priority, candidate.priority);
      duplicate.entries.sort(
        (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
      );
      continue;
    }

    kept.push({
      ...candidate,
      entries: sortedEntries(candidate.entries),
    });
  }

  return kept;
}

function analyzeEvolution(entries: JournalEntry[]): ConversationThreadEvolution {
  if (entries.length < MIN_THREAD_ENTRIES) {
    return { whatChanged: null, whatFaded: null, whatCameBack: null };
  }

  let whatChanged: string | null = null;
  let whatFaded: string | null = null;
  let whatCameBack: string | null = null;

  if (entries.length >= 3) {
    const mid = Math.floor(entries.length / 2);
    const early = entries.slice(0, mid);
    const late = entries.slice(mid);
    const earlyAvg = roundAvg(early.map((e) => e.reflection.emotionalIntensity));
    const lateAvg = roundAvg(late.map((e) => e.reflection.emotionalIntensity));
    const earlyHedge = roundAvg(early.map((e) => countMatches(e.transcript, HEDGE_RE)));
    const lateHedge = roundAvg(late.map((e) => countMatches(e.transcript, HEDGE_RE)));
    const earlyDirect = roundAvg(early.map((e) => countMatches(e.transcript, DIRECT_RE)));
    const lateDirect = roundAvg(late.map((e) => countMatches(e.transcript, DIRECT_RE)));

    if (lateAvg <= earlyAvg - 1 || lateHedge <= earlyHedge - 0.8) {
      whatChanged = "You sounded calmer about this lately.";
    } else if (lateAvg >= earlyAvg + 1) {
      whatChanged = "This took up more room lately.";
    } else if (lateDirect >= earlyDirect + 0.8) {
      whatChanged = "Your language around this shifted over time.";
    }
  }

  for (let i = 1; i < entries.length - 1; i += 1) {
    const gap = daysBetweenKeys(
      toDayKey(entries[i - 1].createdAt),
      toDayKey(entries[i].createdAt),
    );
    if (gap >= GAP_DAYS) {
      whatFaded = "This went quiet for a while.";
      break;
    }
  }

  if (entries.length >= 2) {
    const prev = entries[entries.length - 2];
    const last = entries[entries.length - 1];
    const returnGap = daysBetweenKeys(
      toDayKey(prev.createdAt),
      toDayKey(last.createdAt),
    );
    if (returnGap >= GAP_DAYS) {
      whatCameBack = "You picked this up again later.";
    }
  }

  return { whatChanged, whatFaded, whatCameBack };
}

function toConversationThread(raw: RawThread, slugCounts: Map<string, number>): ConversationThread {
  const entries = sortedEntries(raw.entries);
  const first = entries[0];
  const last = entries[entries.length - 1];
  const baseSlug = toSlug(raw.title);
  const count = (slugCounts.get(baseSlug) ?? 0) + 1;
  slugCounts.set(baseSlug, count);
  const slug = count > 1 ? `${baseSlug}-${count}` : baseSlug;

  const relatedEntries: ConversationThreadEntry[] = entries
    .slice(-MAX_RELATED_ENTRIES)
    .map((entry) => ({
      entryId: entry.id,
      dateLabel: formatEntryDate(entry.createdAt),
      snippet: snippet(entry),
    }));

  return {
    id: `thread-${raw.source}-${textKey(raw.title)}`,
    slug,
    title: raw.title,
    source: raw.source,
    entryIds: entries.map((e) => e.id),
    firstAppearance: first.createdAt,
    latestAppearance: last.createdAt,
    firstAppearanceLabel: formatShortDate(first.createdAt),
    latestAppearanceLabel: formatShortDate(last.createdAt),
    mentionCount: entries.length,
    relatedEntries,
    evolution: analyzeEvolution(entries),
  };
}

/** Build recurring conversation threads from themes, people, phrases, and topics. */
export function buildConversationThreadsReport(
  entries: JournalEntry[],
): ConversationThreadReport {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ARCHIVE_ENTRIES) {
    return { threads: [], hasData: false };
  }

  const raw = dedupeRawThreads([
    ...buildThemeThreads(sorted),
    ...buildEntityThreads(sorted),
    ...buildPhraseThreads(sorted),
  ]);

  const slugCounts = new Map<string, number>();
  const threads = raw
    .map((row) => toConversationThread(row, slugCounts))
    .sort((a, b) => {
      const timeDiff =
        new Date(b.latestAppearance).getTime() -
        new Date(a.latestAppearance).getTime();
      if (timeDiff !== 0) return timeDiff;
      return b.mentionCount - a.mentionCount;
    });

  return { threads, hasData: threads.length > 0 };
}

export function listConversationThreads(
  entries: JournalEntry[],
  limit?: number,
): ConversationThread[] {
  const { threads } = buildConversationThreadsReport(entries);
  return limit ? threads.slice(0, limit) : threads;
}

export function getConversationThreadBySlug(
  entries: JournalEntry[],
  slug: string,
): ConversationThread | null {
  const { threads } = buildConversationThreadsReport(entries);
  return threads.find((thread) => thread.slug === slug) ?? null;
}

export function threadsForEntry(
  entries: JournalEntry[],
  entryId: string,
  limit = 3,
): ConversationThread[] {
  return listConversationThreads(entries)
    .filter((thread) => thread.entryIds.includes(entryId))
    .slice(0, limit);
}

export function memoryThreadHighlights(
  entries: JournalEntry[],
  limit = 4,
): ConversationThread[] {
  return listConversationThreads(entries, limit);
}

export function timelineThreadHighlights(
  entries: JournalEntry[],
  limit = 3,
): ConversationThread[] {
  return listConversationThreads(entries)
    .filter((thread) => thread.mentionCount >= 2)
    .slice(0, limit);
}

export function formatThreadDateRange(thread: ConversationThread): string {
  const start = thread.firstAppearanceLabel;
  const end = thread.latestAppearanceLabel;
  return start === end ? start : `${start} – ${end}`;
}

export function formatThreadSourceLabel(source: ConversationThreadSource): string {
  const labels: Record<ConversationThreadSource, string> = {
    theme: "Theme",
    person: "Person",
    phrase: "Phrase",
    topic: "Topic",
  };
  return labels[source];
}

export function threadRecencyLabel(thread: ConversationThread): string {
  return formatRelativeDate(thread.latestAppearance);
}

export interface ThreadDepthSignals {
  connectedThreadCount: number;
  multiWeekThreadCount: number;
  multiMonthThreadCount: number;
  strongThreadCount: number;
  toneShiftThreadCount: number;
}

/** Measure thread continuity for archive-depth — internal scoring only. */
export function measureThreadDepthSignals(entries: JournalEntry[]): ThreadDepthSignals {
  const { threads } = buildConversationThreadsReport(entries);
  let multiWeekThreadCount = 0;
  let multiMonthThreadCount = 0;
  let toneShiftThreadCount = 0;

  for (const thread of threads) {
    const span = daysBetweenKeys(
      toDayKey(thread.firstAppearance),
      toDayKey(thread.latestAppearance),
    );
    if (span >= 14) multiWeekThreadCount += 1;
    if (span >= 28) multiMonthThreadCount += 1;
    if (thread.evolution.whatChanged || thread.evolution.whatCameBack) {
      toneShiftThreadCount += 1;
    }
  }

  return {
    connectedThreadCount: threads.filter((thread) => thread.mentionCount >= 2).length,
    multiWeekThreadCount,
    multiMonthThreadCount,
    strongThreadCount: threads.filter((thread) => thread.mentionCount >= 3).length,
    toneShiftThreadCount,
  };
}
