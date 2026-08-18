import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { entryRevisitRewardCandidates } from "@/lib/refinement/knows-me-moments";
import {
  pickReopenFirstLine,
  pickStrongestReopenMoment,
  REOPEN_PAYOFF_MIN,
} from "@/lib/refinement/reopen-payoff";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { buildEmotionalTerritoriesReport } from "@/lib/territories/emotional-territories";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { RESURFACING_COPY } from "@/lib/revisit/resurfacing-copy";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export interface FirstMeaningfulRevisitCandidate {
  entryId: string;
  anchorEntryId?: string;
  payoffScore: number;
  firstLine: string;
  signals: string[];
  reasons: string[];
}

const HEDGE_RE = /\b(maybe|sort of|kind of|not sure|i guess|perhaps)\b/gi;
const SOFTENED_RE = /\b(clearer|named|decided|lighter|calmer|for sure|directly)\b/gi;

function hedgeDensity(text: string): number {
  const matches = text.match(HEDGE_RE);
  return matches?.length ?? 0;
}

function uncertaintySoftenedPair(earlier: JournalEntry, later: JournalEntry): boolean {
  const earlyText = `${earlier.transcript} ${earlier.reflection.concreteObservation ?? ""}`;
  const lateText = `${later.transcript} ${later.reflection.concreteObservation ?? ""}`;
  return hedgeDensity(earlyText) >= 2 && SOFTENED_RE.test(lateText);
}

function collectAllRevisitCandidates(entries: JournalEntry[]): MemoryNote[] {
  const pool: MemoryNote[] = [];
  const seen = new Set<string>();
  for (const entry of entries) {
    for (const note of entryRevisitRewardCandidates(entries, entry.id)) {
      if (seen.has(note.id)) continue;
      seen.add(note.id);
      pool.push(note);
    }
  }
  return pool;
}

/** Pick one entry likely to produce “Oh. I remember this.” — memory-first, not analysis copy. */
export function pickFirstMeaningfulRevisitCandidate(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): FirstMeaningfulRevisitCandidate | null {
  if (entries.length < 2) return null;

  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );

  const pool = collectAllRevisitCandidates(sorted);
  const { moment, score } = pickStrongestReopenMoment(pool, sorted);
  if (moment && score && score.total >= REOPEN_PAYOFF_MIN && moment.entryId) {
    return {
      entryId: moment.entryId,
      anchorEntryId: moment.pastEntryId,
      payoffScore: score.total,
      firstLine: pickReopenFirstLine(moment, sorted, score),
      signals: score.signals.map((row) => row.id),
      reasons: ["emotional_contrast", "reopen_payoff"],
    };
  }

  for (let i = 0; i < sorted.length - 1; i += 1) {
    if (uncertaintySoftenedPair(sorted[i], sorted[i + 1])) {
      return {
        entryId: sorted[i].id,
        anchorEntryId: sorted[i + 1].id,
        payoffScore: 62,
        firstLine: RESURFACING_COPY.namedMoreDirectly,
        signals: ["uncertainty_softened"],
        reasons: ["hedge_to_clarity"],
      };
    }
  }

  const phraseMemory = buildPhraseMemory(sorted);
  const topPhrase = phraseMemory.find((row) => row.count >= 2);
  if (topPhrase) {
    const match = sorted.find((entry) =>
      entry.transcript.toLowerCase().includes(topPhrase.phrase.toLowerCase().slice(0, 20)),
    );
    if (match) {
      const latest = sorted[sorted.length - 1];
      const gap = daysBetweenKeys(toDayKey(match.createdAt), toDayKey(latest.createdAt));
      return {
        entryId: match.id,
        payoffScore: 58,
        firstLine:
          gap >= 7
            ? RESURFACING_COPY.similarDaysAgo(gap)
            : RESURFACING_COPY.stillCircling,
        signals: ["repeated_phrase"],
        reasons: ["phrase_recurrence"],
      };
    }
  }

  const withPhoto = sorted.filter((entry) => Boolean(entry.photo?.photoId));
  if (withPhoto.length > 0) {
    const photo = withPhoto[withPhoto.length - 1];
    return {
      entryId: photo.id,
      payoffScore: 56,
      firstLine: RESURFACING_COPY.usedToSoundHeavier,
      signals: ["photo_linked"],
      reasons: ["photo_attachment"],
    };
  }

  const territoryReport = buildEmotionalTerritoriesReport(sorted);
  const forming = territoryReport.territories.find((t) => t.entryIds.length >= 2);
  if (forming && forming.entryIds[0]) {
    return {
      entryId: forming.entryIds[0],
      payoffScore: 55,
      firstLine: `Something was gathering around ${forming.label.toLowerCase()}.`,
      signals: ["territory_emergence"],
      reasons: ["territory_forming"],
    };
  }

  const oldest = sorted[0];
  const gap = daysBetweenKeys(toDayKey(oldest.createdAt), toDayKey(sorted[sorted.length - 1].createdAt));
  if (gap >= 2) {
    return {
      entryId: oldest.id,
      payoffScore: 50,
      firstLine: RESURFACING_COPY.similarDaysAgo(gap),
      signals: ["temporal_distance"],
      reasons: ["earliest_in_week"],
    };
  }

  return null;
}
