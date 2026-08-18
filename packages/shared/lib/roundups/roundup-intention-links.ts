import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import {
  entriesMentioningIntention,
  normalizeIntentionKey,
  readLongTermIntentions,
  syncLongTermIntentions,
} from "@/lib/intentions/long-term-intentions";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { LongTermIntention } from "@/types/long-term-intentions";
import type {
  RoundupIntentionLink,
  RoundupIntentionLinksReport,
  RoundupIntentionLinkSection,
  RoundupPeriod,
} from "@/types/reflective-roundup";

const MAX_LINKS = 3;

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|i don't know|eventually)\b/gi;
const GUILT_RE = /\b(guilty|guilt|should|have to|supposed to)\b/gi;
const URGENCY_RE = /\b(urgent|asap|need to leave|have to quit|can't stay|right away)\b/gi;

interface LinkCandidate {
  text: string;
  intentionId: string;
  entryId: string;
  section: RoundupIntentionLinkSection;
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

function entriesBefore(entries: JournalEntry[], startDayKey: string): JournalEntry[] {
  return sortedEntries(entries).filter((entry) => toDayKey(entry.createdAt) < startDayKey);
}

function entryText(entry: JournalEntry): string {
  return [
    entry.transcript,
    entry.reflection.exactLanguagePattern,
    entry.reflection.concreteObservation,
    entry.reflection.repeatedSignal,
    entry.reflection.tensionOrContradiction,
    entry.reflection.avoidedOrVagueArea,
    ...(entry.reflection.patternObservations ?? []),
  ]
    .filter(Boolean)
    .join("\n");
}

function shortTopic(text: string): string {
  const words = text.trim().split(/\s+/).slice(0, 4);
  const phrase = words.join(" ");
  return phrase.charAt(0).toUpperCase() + phrase.slice(1).toLowerCase();
}

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function toneAround(entries: JournalEntry[]): {
  intensity: number;
  hedge: number;
  guilt: number;
  urgency: number;
} {
  if (entries.length === 0) {
    return { intensity: 0, hedge: 0, guilt: 0, urgency: 0 };
  }

  const text = entries.map(entryText).join("\n");
  return {
    intensity:
      entries.reduce((sum, entry) => sum + entry.reflection.emotionalIntensity, 0) / entries.length,
    hedge: countMatches(text, HEDGE_RE),
    guilt: countMatches(text, GUILT_RE),
    urgency: countMatches(text, URGENCY_RE),
  };
}

function analyzeIntentionInPeriod(
  intention: LongTermIntention,
  period: RoundupPeriod,
  allEntries: JournalEntry[],
): LinkCandidate[] {
  const periodEntries = entriesInRange(allEntries, period.startDayKey, period.endDayKey);
  const beforeEntries = entriesBefore(allEntries, period.startDayKey);
  const inPeriod = entriesMentioningIntention(periodEntries, intention);
  const beforePeriod = entriesMentioningIntention(beforeEntries, intention);

  if (inPeriod.length === 0 && beforePeriod.length === 0) {
    return [];
  }

  const candidates: LinkCandidate[] = [];
  const topic = shortTopic(intention.userLabel ?? intention.text);
  const latestEntryId = inPeriod[inPeriod.length - 1]?.id ?? intention.sourceEntryIds.at(-1) ?? "";

  if (inPeriod.length >= 2) {
    candidates.push({
      text: `${topic} kept coming back.`,
      intentionId: intention.id,
      entryId: latestEntryId,
      section: "still_with_you",
      weight: 78 + inPeriod.length,
    });
  }

  const lastBefore = beforePeriod[beforePeriod.length - 1];
  const firstInPeriod = inPeriod[0];
  if (
    inPeriod.length >= 1 &&
    lastBefore &&
    firstInPeriod &&
    daysBetweenKeys(toDayKey(lastBefore.createdAt), toDayKey(firstInPeriod.createdAt)) >= 14
  ) {
    candidates.push({
      text: `${topic} came back this period.`,
      intentionId: intention.id,
      entryId: firstInPeriod.id,
      section: "still_with_you",
      weight: 74,
    });
  }

  if (inPeriod.length >= 1 && (intention.status === "open" || intention.status === "returned")) {
    const beforeTone = toneAround(beforePeriod.slice(-2));
    const periodTone = toneAround(inPeriod.slice(-2));

    if (beforeTone.guilt > periodTone.guilt + 1 || beforeTone.hedge > periodTone.hedge + 1) {
      candidates.push({
        text: `You spoke about ${topic.toLowerCase()} with less guilt.`,
        intentionId: intention.id,
        entryId: latestEntryId,
        section: "still_with_you",
        weight: 72,
      });
    }
  }

  if (beforePeriod.length > 0 && inPeriod.length > 0) {
    const beforeTone = toneAround(beforePeriod.slice(-2));
    const periodTone = toneAround(inPeriod.slice(-2));

    if (beforeTone.urgency > periodTone.urgency + 0) {
      candidates.push({
        text: `${topic} sounded less urgent.`,
        intentionId: intention.id,
        entryId: latestEntryId,
        section: "changed_shape",
        weight: 76,
      });
    }

    const intensityDelta = periodTone.intensity - beforeTone.intensity;
    if (Math.abs(intensityDelta) >= 1.5) {
      candidates.push({
        text:
          intensityDelta < 0
            ? `${topic} felt lighter when you named it.`
            : `${topic} felt heavier when you named it.`,
        intentionId: intention.id,
        entryId: latestEntryId,
        section: "changed_shape",
        weight: 68,
      });
    }
  }

  if (
    intention.status === "changed" ||
    (beforePeriod.length > 0 &&
      inPeriod.length > 0 &&
      normalizeIntentionKey(beforePeriod[beforePeriod.length - 1]?.reflection.concreteObservation ?? intention.text) !==
        normalizeIntentionKey(inPeriod[inPeriod.length - 1]?.reflection.concreteObservation ?? intention.text))
  ) {
    candidates.push({
      text: "This changed shape.",
      intentionId: intention.id,
      entryId: latestEntryId,
      section: "changed_shape",
      weight: 70,
    });
  }

  if (beforePeriod.length > 0 && inPeriod.length === 0) {
    const recentBefore = beforePeriod.filter(
      (entry) =>
        daysBetweenKeys(toDayKey(entry.createdAt), period.startDayKey) <= 60,
    );
    if (recentBefore.length > 0) {
      candidates.push({
        text: `${topic} got quieter this period.`,
        intentionId: intention.id,
        entryId: recentBefore[recentBefore.length - 1].id,
        section: "quieter_this_period",
        weight: 66,
      });
    }
  }

  if (inPeriod.length === 1 && beforePeriod.length === 0) {
    candidates.push({
      text: `You named ${topic.toLowerCase()} for the first time.`,
      intentionId: intention.id,
      entryId: inPeriod[0].id,
      section: "still_with_you",
      weight: 58,
    });
  }

  return candidates;
}

function pickLinks(candidates: LinkCandidate[]): RoundupIntentionLink[] {
  const usedIntentions = new Set<string>();
  const usedSections = new Set<RoundupIntentionLinkSection>();
  const sorted = [...candidates].sort((a, b) => b.weight - a.weight);
  const picked: RoundupIntentionLink[] = [];

  for (const candidate of sorted) {
    if (picked.length >= MAX_LINKS) break;
    if (usedIntentions.has(candidate.intentionId)) continue;

    if (picked.length < MAX_LINKS - 1 && usedSections.has(candidate.section)) {
      continue;
    }

    usedIntentions.add(candidate.intentionId);
    usedSections.add(candidate.section);
    picked.push({
      id: `roundup-intent-${candidate.intentionId}-${picked.length}`,
      text: candidate.text,
      intentionId: candidate.intentionId,
      entryId: candidate.entryId,
      section: candidate.section,
    });
  }

  return picked;
}

/** Connect a roundup period to long-term intentions — max 3 links, no action plan. */
export function buildRoundupIntentionLinks(
  period: RoundupPeriod,
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): RoundupIntentionLinksReport {
  syncLongTermIntentions(entries);
  const intentions = readLongTermIntentions();
  const periodEntries = entriesInRange(entries, period.startDayKey, period.endDayKey);

  if (periodEntries.length === 0 || intentions.length === 0) {
    return {
      stillWithYou: [],
      changedShape: [],
      quieterThisPeriod: [],
      hasData: false,
    };
  }

  const candidates = intentions.flatMap((intention) =>
    analyzeIntentionInPeriod(intention, period, entries),
  );
  const links = pickLinks(candidates);

  return {
    stillWithYou: links.filter((row) => row.section === "still_with_you"),
    changedShape: links.filter((row) => row.section === "changed_shape"),
    quieterThisPeriod: links.filter((row) => row.section === "quieter_this_period"),
    hasData: links.length > 0,
  };
}
