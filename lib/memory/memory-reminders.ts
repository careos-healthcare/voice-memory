import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import { formatRelativeDate } from "@/lib/utils";
import type {
  MemoryReminder,
  MemoryReminderContext,
  MemoryReminderCopyExample,
  MemoryReminderKind,
  MemoryReminderReport,
} from "@/types/memory-reminder";
import type { JournalEntry } from "@/types/journal";

const REMINDER_KEY = "voicememory_memory_reminders";
const MIN_ENTRIES = 3;
const STRONG_MIN = 62;
const MIN_SESSIONS = 2;
const MIN_DAYS = 5;
const TEXT_COOLDOWN_DAYS = 21;
const OLDER_GAP_DAYS = 12;
const TOPIC_QUIET_DAYS = 14;
const LOOP_GAP_DAYS = 10;

const LOOP_RE =
  /\b(same loop|loop came back|keep coming back|again before|that loop|same pattern|i keep)\b/i;

export interface MemoryReminderOptions {
  context: MemoryReminderContext;
  limit?: number;
  record?: boolean;
}

interface ReminderState {
  sessionCount: number;
  lastSessionDay: string;
  sessionsAtLastShow: number;
  lastShownAt: number;
  records: Array<{
    noteId: string;
    textKey: string;
    surface: MemoryReminderContext;
    shownAt: number;
  }>;
}

const COPY: Record<MemoryReminderKind, string> = {
  old_reflection_revisit: "An older reflection may feel different now.",
  topic_absent: "This has been quiet for a while.",
  resurfaced_loop: "This came back softly.",
  calmer_return: "This came back softly.",
};

const KIND_PRIORITY: MemoryReminderKind[] = [
  "old_reflection_revisit",
  "topic_absent",
  "calmer_return",
  "resurfaced_loop",
];

export const MEMORY_REMINDER_COPY_EXAMPLES: MemoryReminderCopyExample[] = [
  {
    kind: "old_reflection_revisit",
    message: COPY.old_reflection_revisit,
    whenShown: "An older entry shares a thread with your recent reflections, with enough distance to revisit",
  },
  {
    kind: "topic_absent",
    message: COPY.topic_absent,
    whenShown: "A recurring topic has not appeared in your recent reflections for a while",
  },
  {
    kind: "resurfaced_loop",
    message: COPY.resurfaced_loop,
    whenShown: "A familiar loop returned after a gap, with softer language than before",
  },
  {
    kind: "calmer_return",
    message: COPY.calmer_return,
    whenShown: "A topic returned with less tension than earlier mentions",
  },
];

function isBrowser(): boolean {
  return typeof window !== "undefined";
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

function textKey(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 72);
}

function sharedThemes(a: JournalEntry, b: JournalEntry): string[] {
  const setB = new Set(b.reflection.recurringThemes.map((t) => t.toLowerCase()));
  return a.reflection.recurringThemes.filter((t) => setB.has(t.toLowerCase()));
}

function themeMap(sorted: JournalEntry[]): Map<string, JournalEntry[]> {
  const map = new Map<string, JournalEntry[]>();
  for (const entry of sorted) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase();
      map.set(key, [...(map.get(key) ?? []), entry]);
    }
  }
  return map;
}

function readState(): ReminderState {
  if (!isBrowser()) {
    return {
      sessionCount: 0,
      lastSessionDay: "",
      sessionsAtLastShow: 0,
      lastShownAt: 0,
      records: [],
    };
  }
  try {
    const raw = localStorage.getItem(REMINDER_KEY);
    if (!raw) {
      return {
        sessionCount: 0,
        lastSessionDay: "",
        sessionsAtLastShow: 0,
        lastShownAt: 0,
        records: [],
      };
    }
    const parsed = JSON.parse(raw) as ReminderState;
    return {
      sessionCount: parsed.sessionCount ?? 0,
      lastSessionDay: parsed.lastSessionDay ?? "",
      sessionsAtLastShow: parsed.sessionsAtLastShow ?? 0,
      lastShownAt: parsed.lastShownAt ?? 0,
      records: Array.isArray(parsed.records) ? parsed.records : [],
    };
  } catch {
    return {
      sessionCount: 0,
      lastSessionDay: "",
      sessionsAtLastShow: 0,
      lastShownAt: 0,
      records: [],
    };
  }
}

function writeState(state: ReminderState): void {
  if (!isBrowser()) return;
  localStorage.setItem(REMINDER_KEY, JSON.stringify(state));
}

export function bumpMemoryReminderSession(): ReminderState {
  const today = toDayKey(new Date().toISOString());
  const state = readState();
  if (state.lastSessionDay !== today) {
    state.sessionCount += 1;
    state.lastSessionDay = today;
    writeState(state);
  }
  return state;
}

export function clearMemoryReminderFatigue(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(REMINDER_KEY);
}

function daysSince(timestamp: number): number {
  if (!timestamp) return Number.POSITIVE_INFINITY;
  return (Date.now() - timestamp) / (1000 * 60 * 60 * 24);
}

function isTextFatigued(text: string): boolean {
  const key = textKey(text);
  return readState().records.some(
    (record) => record.textKey === key && daysSince(record.shownAt) < TEXT_COOLDOWN_DAYS,
  );
}

function canShowOnHomepage(state: ReminderState): boolean {
  const sessionsSince = state.sessionCount - state.sessionsAtLastShow;
  if (sessionsSince < MIN_SESSIONS) return false;
  if (daysSince(state.lastShownAt) < MIN_DAYS) return false;
  return true;
}

function recordReminderShown(
  reminder: MemoryReminder,
  context: MemoryReminderContext,
): void {
  const state = readState();
  const now = Date.now();
  state.lastShownAt = now;
  state.sessionsAtLastShow = state.sessionCount;
  state.records = [
    ...state.records,
    {
      noteId: reminder.id,
      textKey: textKey(reminder.text),
      surface: context,
      shownAt: now,
    },
  ].slice(-24);
  writeState(state);
}

function evidencePair(past: JournalEntry, current?: JournalEntry) {
  return {
    pastQuote: snippet(past),
    currentQuote: current ? snippet(current) : undefined,
    pastDateLabel: formatRelativeDate(past.createdAt),
    currentDateLabel: current ? formatRelativeDate(current.createdAt) : undefined,
    pastEntryId: past.id,
    entryId: current?.id,
  };
}

function hasEvidence(
  item: Pick<MemoryReminder, "pastQuote" | "pastDateLabel" | "pastEntryId">,
): boolean {
  if (item.pastQuote?.trim() && item.pastDateLabel) return true;
  if (item.pastEntryId && item.pastDateLabel) return true;
  return false;
}

function pushCandidate(
  bucket: MemoryReminder[],
  item: Omit<MemoryReminder, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (strength < STRONG_MIN) return;
  if (!hasEvidence(item)) return;
  if (!helpsOrient(item.text, strength)) return;
  if (isTextFatigued(item.text)) return;
  bucket.push({ ...item, strength });
}

function detectOldReflectionRevisit(
  latest: JournalEntry,
  prior: JournalEntry[],
): MemoryReminder[] {
  const notes: MemoryReminder[] = [];
  const latestDay = toDayKey(latest.createdAt);

  for (let i = prior.length - 1; i >= 0; i -= 1) {
    const old = prior[i];
    const gap = daysBetweenKeys(toDayKey(old.createdAt), latestDay);
    if (gap < OLDER_GAP_DAYS) continue;

    const overlap = sharedThemes(old, latest);
    const meaningful =
      overlap.length > 0 ||
      old.reflection.emotionalIntensity >= 6 ||
      latest.reflection.emotionalIntensity >= 6;
    if (!meaningful) continue;

    pushCandidate(notes, {
      id: `mem-reminder-old-${old.id}`,
      kind: "old_reflection_revisit",
      text: COPY.old_reflection_revisit,
      strength: 64 + Math.min(gap, 12) + overlap.length * 2,
      href: `/entry/${old.id}`,
      ...evidencePair(old, latest),
    });
    break;
  }

  return notes;
}

function detectTopicAbsent(sorted: JournalEntry[]): MemoryReminder[] {
  const notes: MemoryReminder[] = [];
  if (sorted.length < MIN_ENTRIES) return notes;

  const latest = sorted[sorted.length - 1];
  const today = toDayKey(latest.createdAt);
  const recentIds = new Set(sorted.slice(-3).map((entry) => entry.id));

  for (const [themeKey, hits] of themeMap(sorted)) {
    if (hits.length < 3) continue;

    const lastHit = hits[hits.length - 1];
    if (recentIds.has(lastHit.id)) continue;

    const gap = daysBetweenKeys(toDayKey(lastHit.createdAt), today);
    if (gap < TOPIC_QUIET_DAYS) continue;

    pushCandidate(notes, {
      id: `mem-reminder-quiet-${themeKey}-${lastHit.id}`,
      kind: "topic_absent",
      text: COPY.topic_absent,
      strength: 63 + Math.min(gap, 14) + hits.length,
      href: `/entry/${lastHit.id}`,
      ...evidencePair(lastHit),
    });
    break;
  }

  return notes;
}

function detectResurfacedLoop(
  latest: JournalEntry,
  prior: JournalEntry[],
): MemoryReminder[] {
  const notes: MemoryReminder[] = [];
  const latestDay = toDayKey(latest.createdAt);
  const hasLoopCue =
    LOOP_RE.test(latest.transcript) ||
    latest.reflection.recurringThemes.some((theme) =>
      /\b(loop|pattern|again)\b/i.test(theme),
    );
  if (!hasLoopCue) return notes;

  for (let i = prior.length - 1; i >= 0; i -= 1) {
    const old = prior[i];
    const gap = daysBetweenKeys(toDayKey(old.createdAt), latestDay);
    if (gap < LOOP_GAP_DAYS) continue;

    const overlap = sharedThemes(old, latest);
    const hadLoop = LOOP_RE.test(old.transcript) || overlap.length > 0;
    if (!hadLoop) continue;

    const softer = latest.reflection.emotionalIntensity <= old.reflection.emotionalIntensity - 0.5;
    if (!softer && !LOOP_RE.test(latest.transcript)) continue;

    pushCandidate(notes, {
      id: `mem-reminder-loop-${old.id}-${latest.id}`,
      kind: "resurfaced_loop",
      text: COPY.resurfaced_loop,
      strength: 65 + Math.min(gap, 10),
      href: `/entry/${latest.id}`,
      ...evidencePair(old, latest),
    });
    break;
  }

  return notes;
}

function detectCalmerReturn(
  latest: JournalEntry,
  prior: JournalEntry[],
): MemoryReminder[] {
  const notes: MemoryReminder[] = [];
  const latestDay = toDayKey(latest.createdAt);

  for (const theme of latest.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const priorHits = prior.filter((entry) =>
      entry.reflection.recurringThemes.some((t) => t.toLowerCase() === themeKey),
    );
    if (priorHits.length < 2) continue;

    const lastPrior = priorHits[priorHits.length - 1];
    const gap = daysBetweenKeys(toDayKey(lastPrior.createdAt), latestDay);
    if (gap < TOPIC_QUIET_DAYS) continue;

    const priorAvg = roundAvg(priorHits.map((entry) => entry.reflection.emotionalIntensity));
    if (latest.reflection.emotionalIntensity > priorAvg - 1.2) continue;

    pushCandidate(notes, {
      id: `mem-reminder-calmer-${themeKey}-${latest.id}`,
      kind: "calmer_return",
      text: COPY.calmer_return,
      strength: 64 + Math.round(priorAvg - latest.reflection.emotionalIntensity) * 3,
      href: `/entry/${latest.id}`,
      ...evidencePair(lastPrior, latest),
    });
    break;
  }

  return notes;
}

function collectCandidates(sorted: JournalEntry[]): MemoryReminder[] {
  if (sorted.length < MIN_ENTRIES) return [];

  const latest = sorted[sorted.length - 1];
  const prior = sorted.slice(0, -1);

  return [
    ...detectOldReflectionRevisit(latest, prior),
    ...detectTopicAbsent(sorted),
    ...detectCalmerReturn(latest, prior),
    ...detectResurfacedLoop(latest, prior),
  ];
}

function dedupeReminders(reminders: MemoryReminder[]): MemoryReminder[] {
  const seen = new Set<string>();
  return reminders
    .filter((reminder) => reminder.strength >= USEFULNESS_MIN_CONFIDENCE)
    .sort((a, b) => b.strength - a.strength)
    .filter((reminder) => {
      const key = `${reminder.kind}:${reminder.text}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function pickReminders(
  candidates: MemoryReminder[],
  limit: number,
): MemoryReminder[] {
  const sorted = dedupeReminders(candidates);
  const picked: MemoryReminder[] = [];
  const usedKinds = new Set<MemoryReminderKind>();

  for (const kind of KIND_PRIORITY) {
    const match = sorted.find((reminder) => reminder.kind === kind && !usedKinds.has(kind));
    if (match) {
      picked.push(match);
      usedKinds.add(kind);
    }
    if (picked.length >= limit) break;
  }

  if (picked.length < limit) {
    for (const reminder of sorted) {
      if (picked.length >= limit) break;
      if (picked.some((p) => p.id === reminder.id)) continue;
      picked.push(reminder);
    }
  }

  return picked.slice(0, limit);
}

/** Build sparse memory reminders from archive patterns. */
export function buildMemoryRemindersReport(
  entries: JournalEntry[],
  options: MemoryReminderOptions,
): MemoryReminderReport {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ENTRIES) {
    return { reminders: [], hasData: false };
  }

  const limit = options.limit ?? 1;
  const candidates = collectCandidates(sorted);

  if (options.context === "homepage") {
    const state = bumpMemoryReminderSession();
    if (!canShowOnHomepage(state)) {
      return { reminders: [], hasData: false };
    }
  }

  const reminders = pickReminders(candidates, limit);

  if (reminders.length > 0 && options.record !== false && options.context === "homepage") {
    recordReminderShown(reminders[0], options.context);
  }

  return { reminders, hasData: reminders.length > 0 };
}

export function homepageMemoryReminder(entries: JournalEntry[]): MemoryReminder | null {
  return buildMemoryRemindersReport(entries, { context: "homepage", limit: 1 }).reminders[0] ?? null;
}

export function listMemoryReminders(
  entries: JournalEntry[],
  limit = 4,
): MemoryReminder[] {
  return buildMemoryRemindersReport(entries, {
    context: "reminders",
    limit,
    record: false,
  }).reminders;
}
