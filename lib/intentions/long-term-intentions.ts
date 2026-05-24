import { addDaysToKey, daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  IntentionStatus,
  IntentionsReport,
  LongTermIntention,
} from "@/types/long-term-intentions";

const STORAGE_KEY = "voicememory_long_term_intentions";
const MAX_INTENTIONS = 80;
const FADE_AFTER_DAYS = 42;
const RETURN_GAP_DAYS = 14;

const INTENTION_PATTERNS: RegExp[] = [
  /\bi want(?:ed)? to?\s+([^.!?\n]{4,72})/gi,
  /\bi keep meaning to\s+([^.!?\n]{4,72})/gi,
  /\bi need to\s+([^.!?\n]{4,72})/gi,
  /\bi wish(?:ed)?\s+([^.!?\n]{4,72})/gi,
  /\bi(?:'d| would) like to\s+([^.!?\n]{4,72})/gi,
  /\bi keep thinking i should\s+([^.!?\n]{4,72})/gi,
  /\bi still need to\s+([^.!?\n]{4,72})/gi,
  /\bi haven't(?: yet)?\s+([^.!?\n]{4,72})/gi,
  /\beventually i(?:'ll| will)\s+([^.!?\n]{4,72})/gi,
  /\bsomeday i(?:'ll| will)?\s+([^.!?\n]{4,72})/gi,
  /\bone day i(?:'ll| will)?\s+([^.!?\n]{4,72})/gi,
  /\bwhen i finally\s+([^.!?\n]{4,72})/gi,
  /\bfuture me (?:will|would|should)\s+([^.!?\n]{4,72})/gi,
  /\bi hope to\s+([^.!?\n]{4,72})/gi,
];

const GENERIC_FRAGMENTS = [
  /^be better$/,
  /^do better$/,
  /^feel better$/,
  /^get better$/,
  /^figure it out$/,
  /^work on myself$/,
  /^sort myself out$/,
];

interface RawMention {
  text: string;
  entryId: string;
  seenAt: string;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function readStoreRaw(): LongTermIntention[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as LongTermIntention[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeStoreRaw(intentions: LongTermIntention[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(STORAGE_KEY, JSON.stringify(intentions.slice(0, MAX_INTENTIONS)));
}

function cleanFragment(raw: string): string | null {
  let phrase = raw.trim().replace(/\s+/g, " ").replace(/[.,;:!?]+$/, "");
  phrase = phrase.replace(/^(that|this|the|a|an|to|just)\s+/i, "");
  if (phrase.length < 8 || phrase.length > 72) return null;
  const lower = phrase.toLowerCase();
  if (GENERIC_FRAGMENTS.some((re) => re.test(lower))) return null;
  if (/\b(task|todo|smart goal|deadline|productivity)\b/i.test(lower)) return null;
  return lower.charAt(0).toUpperCase() + lower.slice(1);
}

function intentionKey(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 64);
}

function entryText(entry: JournalEntry): string {
  return [
    entry.transcript,
    entry.reflection.exactLanguagePattern,
    entry.reflection.concreteObservation,
    entry.reflection.repeatedSignal,
    entry.reflection.nextSmallAction,
    entry.reflection.tensionOrContradiction,
    ...(entry.reflection.patternObservations ?? []),
  ]
    .filter(Boolean)
    .join("\n");
}

function extractMentions(entries: JournalEntry[]): RawMention[] {
  const mentions: RawMention[] = [];
  const seenInEntry = new Set<string>();

  for (const entry of sortedEntries(entries)) {
    const text = entryText(entry);
    seenInEntry.clear();

    for (const pattern of INTENTION_PATTERNS) {
      const re = new RegExp(pattern.source, pattern.flags);
      for (const match of text.matchAll(re)) {
        const fragment = cleanFragment(match[1] ?? match[0]);
        if (!fragment) continue;
        const dedupe = `${entry.id}:${intentionKey(fragment)}`;
        if (seenInEntry.has(dedupe)) continue;
        seenInEntry.add(dedupe);
        mentions.push({
          text: fragment,
          entryId: entry.id,
          seenAt: entry.createdAt,
        });
      }
    }

    const goal = entry.reflection.nextSmallAction?.trim();
    if (goal && goal.length >= 8) {
      const fragment = cleanFragment(goal);
      if (fragment) {
        const dedupe = `${entry.id}:${intentionKey(fragment)}`;
        if (!seenInEntry.has(dedupe)) {
          mentions.push({ text: fragment, entryId: entry.id, seenAt: entry.createdAt });
        }
      }
    }
  }

  return mentions;
}

function findMatchingIntention(
  intentions: LongTermIntention[],
  text: string,
): LongTermIntention | undefined {
  const key = intentionKey(text);
  return intentions.find((row) => {
    const rowKey = intentionKey(row.text);
    return rowKey === key || rowKey.startsWith(key.slice(0, 24)) || key.startsWith(rowKey.slice(0, 24));
  });
}

function textDrift(a: string, b: string): boolean {
  const keyA = intentionKey(a);
  const keyB = intentionKey(b);
  if (keyA === keyB) return false;
  const shorter = keyA.length < keyB.length ? keyA : keyB;
  const longer = keyA.length >= keyB.length ? keyA : keyB;
  return longer.includes(shorter.slice(0, Math.min(20, shorter.length))) === false;
}

function refreshedStatus(
  intention: LongTermIntention,
  mentionAt: string,
  nextText: string,
  revisitedEntryIds: Set<string>,
): IntentionStatus {
  const gapDays = daysBetweenKeys(toDayKey(intention.lastSeenAt), toDayKey(mentionAt));
  const daysSinceMention = daysBetweenKeys(toDayKey(mentionAt), todayKey());

  if (textDrift(intention.text, nextText)) {
    return "changed";
  }

  if (revisitedEntryIds.has(intention.sourceEntryIds[intention.sourceEntryIds.length - 1] ?? "")) {
    return "returned";
  }

  if (gapDays >= RETURN_GAP_DAYS && daysSinceMention <= 21) {
    return "returned";
  }

  if (daysSinceMention > FADE_AFTER_DAYS) {
    return "faded";
  }

  return "open";
}

function applyFadePass(intentions: LongTermIntention[]): LongTermIntention[] {
  const today = todayKey();
  return intentions.map((row) => {
    if (row.status === "changed") return row;
    const daysSince = daysBetweenKeys(toDayKey(row.lastSeenAt), today);
    if (daysSince > FADE_AFTER_DAYS) {
      return { ...row, status: "faded" as const };
    }
    if (row.status === "faded" && daysSince <= 21) {
      return { ...row, status: "returned" as const };
    }
    return row;
  });
}

function revisitedEntryIds(): Set<string> {
  const ids = new Set<string>();
  for (const event of readRetentionLoopEvents()) {
    for (const id of [event.targetEntryId, event.pastEntryId, event.entryId]) {
      if (id) ids.add(id);
    }
  }
  return ids;
}

/** Scan archive and merge intention mentions into local storage. */
export function syncLongTermIntentions(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): LongTermIntention[] {
  const mentions = extractMentions(entries);
  let intentions = readStoreRaw();
  const revisits = revisitedEntryIds();

  for (const mention of mentions) {
    const existing = findMatchingIntention(intentions, mention.text);
    if (existing) {
      const sourceEntryIds = existing.sourceEntryIds.includes(mention.entryId)
        ? existing.sourceEntryIds
        : [...existing.sourceEntryIds, mention.entryId].slice(-12);
      const lastSeenAt =
        new Date(mention.seenAt).getTime() > new Date(existing.lastSeenAt).getTime()
          ? mention.seenAt
          : existing.lastSeenAt;
      const firstSeenAt =
        new Date(mention.seenAt).getTime() < new Date(existing.firstSeenAt).getTime()
          ? mention.seenAt
          : existing.firstSeenAt;

      const updated: LongTermIntention = {
        ...existing,
        text: mention.text,
        sourceEntryIds,
        firstSeenAt,
        lastSeenAt,
        status: refreshedStatus(existing, mention.seenAt, mention.text, revisits),
      };
      intentions = intentions.map((row) => (row.id === existing.id ? updated : row));
    } else {
      intentions.push({
        id: `intent-${crypto.randomUUID()}`,
        text: mention.text,
        sourceEntryIds: [mention.entryId],
        firstSeenAt: mention.seenAt,
        lastSeenAt: mention.seenAt,
        status: "open",
      });
    }
  }

  intentions = applyFadePass(intentions);
  intentions.sort(
    (a, b) => new Date(b.lastSeenAt).getTime() - new Date(a.lastSeenAt).getTime(),
  );
  writeStoreRaw(intentions);
  return intentions;
}

export function readLongTermIntentions(): LongTermIntention[] {
  return readStoreRaw().sort(
    (a, b) => new Date(b.lastSeenAt).getTime() - new Date(a.lastSeenAt).getTime(),
  );
}

export function setIntentionUserLabel(intentionId: string, userLabel: string): LongTermIntention | null {
  const trimmed = userLabel.trim().slice(0, 80);
  const intentions = readStoreRaw();
  const index = intentions.findIndex((row) => row.id === intentionId);
  if (index < 0) return null;

  intentions[index] = {
    ...intentions[index],
    userLabel: trimmed || undefined,
  };
  writeStoreRaw(intentions);
  return intentions[index];
}

export function buildIntentionsReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): IntentionsReport {
  const intentions = syncLongTermIntentions(entries);

  const stillOpen = intentions.filter((row) => row.status === "open" || row.status === "returned");
  const changedOverTime = intentions.filter((row) => row.status === "changed");
  const fadedForNow = intentions.filter((row) => row.status === "faded");

  return {
    generatedAt: new Date().toISOString(),
    stillOpen,
    changedOverTime,
    fadedForNow,
    hasData: intentions.length > 0,
  };
}

export function formatIntentionSpan(intention: LongTermIntention): string {
  const first = toDayKey(intention.firstSeenAt);
  const last = toDayKey(intention.lastSeenAt);
  if (first === last) return first;
  return `${first} – ${last}`;
}

export function nextFadeCheckDay(intention: LongTermIntention): string {
  return addDaysToKey(toDayKey(intention.lastSeenAt), FADE_AFTER_DAYS);
}
