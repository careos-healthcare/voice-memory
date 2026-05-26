import { addDaysToKey, daysBetweenKeys, toDayKey } from "@/lib/dates";
import {
  buildLanguageFingerprint,
  currentCircleRun,
  directCount,
  FAMILIARITY_COPY,
  fingerprintEvidence,
  hedgeCount,
  isLooping,
  type LanguageFingerprint,
  MIN_FINGERPRINT_ENTRIES,
} from "@/lib/memory/language-fingerprint";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import {
  getThemeIntensityTrend,
  hasTheme,
  languageShiftOnTheme,
} from "@/lib/patterns/emotional-evolution";
import { helpsOrient } from "@/lib/patterns/usefulness-filter";
import {
  directScore,
  hedgeScore,
  rankThenVsNowContrastNotes,
} from "@/lib/refinement/then-vs-now-quotes";
import { rankReopenPayoffNotes } from "@/lib/refinement/reopen-payoff";
import { gateDelayedPayoffNote } from "@/lib/memory/delayed-payoff";
import { guardSurfacedNote, filterFalsePositiveNotes } from "@/lib/refinement/false-positive-suppression";
import {
  isTopicRecurrenceCopy,
  REVISIT_REWARD_COPY,
  type RevisitRewardCopyLine,
} from "@/lib/refinement/revisit-reward-copy";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export {
  REVISIT_REWARD_COPY,
  TOPIC_RECURRENCE_TEXT,
  isTopicRecurrenceCopy,
} from "@/lib/refinement/revisit-reward-copy";

export const KNOWS_ME_VISIT_MIN = 58;
export const KNOWS_ME_SURFACE_MIN = 72;

export type KnowsMeSignal =
  | "emotional_contrast"
  | "wording_shift"
  | "certainty_shift"
  | "directness_shift"
  | "weight_shift"
  | "topic_quieter"
  | "phrase_gone"
  | "direct_naming"
  | "earlier_self";

export type KnowsMeSurface = "entry" | "homepage" | "timeline" | "monthly";

export const KNOWS_ME_COPY = {
  used_to_feel_heavier: "This used to feel heavier.",
  still_circling: "You were still circling this here.",
  stopped_apologising: "You stopped apologising when talking about this.",
  sound_more_direct: "You sound more direct now.",
  earlier_version: "You sound like an earlier you here.",
} as const;

const APOLOGY_RE = /\b(sorry|apolog\w*)\b/i;

const SELF_CONTRAST_SIGNALS = new Set<KnowsMeSignal>([
  "earlier_self",
  "wording_shift",
  "weight_shift",
  "direct_naming",
  "certainty_shift",
  "directness_shift",
  "phrase_gone",
  "emotional_contrast",
]);

export {
  prepareRevisitContrastNote,
  qualifiesRevisitQuoteContrast,
  trimRevisitQuote,
} from "@/lib/refinement/then-vs-now-quotes";

export function revisitRewardCopyForContrast(
  note: MemoryNote,
  entries: JournalEntry[],
): RevisitRewardCopyLine {
  const past = note.pastEntryId
    ? entries.find((entry) => entry.id === note.pastEntryId)
    : undefined;
  const current = note.entryId
    ? entries.find((entry) => entry.id === note.entryId)
    : undefined;

  if (note.pastQuote && note.currentQuote) {
    const hedgeDrop = hedgeScore(note.pastQuote) - hedgeScore(note.currentQuote);
    const directGain = directScore(note.currentQuote) - directScore(note.pastQuote);
    if (hedgeDrop >= 1 && directGain >= 0) return REVISIT_REWARD_COPY.notNamedYet;
    if (directGain >= 1) return REVISIT_REWARD_COPY.notNamedYet;
  }

  const signal = signalFromNoteId(note);
  if (signal === "direct_naming" || signal === "certainty_shift" || signal === "directness_shift") {
    return REVISIT_REWARD_COPY.notNamedYet;
  }
  if (signal === "weight_shift") return REVISIT_REWARD_COPY.usedToTakeSpace;
  if (signal === "topic_quieter") return REVISIT_REWARD_COPY.soundFurtherAway;

  if (past && current) {
    if (current.reflection.emotionalIntensity <= past.reflection.emotionalIntensity - 1) {
      return REVISIT_REWARD_COPY.soundFurtherAway;
    }
    if (past.reflection.mood !== current.reflection.mood) {
      return REVISIT_REWARD_COPY.soundDifferentNow;
    }
  }

  return REVISIT_REWARD_COPY.soundDifferentNow;
}

const REVISIT_CONTRAST_PRIORITY: KnowsMeSignal[] = [
  "earlier_self",
  "wording_shift",
  "weight_shift",
  "direct_naming",
  "certainty_shift",
  "directness_shift",
  "phrase_gone",
  "emotional_contrast",
  "topic_quieter",
];

const REVISIT_REWARD_LINE_PRIORITY: KnowsMeSignal[] = [
  "earlier_self",
  "wording_shift",
  "weight_shift",
  "direct_naming",
  "certainty_shift",
  "directness_shift",
  "phrase_gone",
  "emotional_contrast",
  "topic_quieter",
];

interface KnowsMeCandidate {
  id: string;
  text: string;
  signal: KnowsMeSignal;
  strength: number;
  pastQuote?: string;
  currentQuote?: string;
  pastDateLabel?: string;
  currentDateLabel?: string;
  pastEntryId?: string;
  entryId?: string;
}

const ABSENCE_DAYS = 14;

const SIGNAL_PRIORITY: KnowsMeSignal[] = [
  "earlier_self",
  "wording_shift",
  "weight_shift",
  "direct_naming",
  "certainty_shift",
  "directness_shift",
  "phrase_gone",
  "emotional_contrast",
  "topic_quieter",
];

function apologyCount(entry: JournalEntry): number {
  return entry.transcript.match(APOLOGY_RE)?.length ?? 0;
}

function entriesForCandidate(
  candidate: KnowsMeCandidate,
  allSorted: JournalEntry[],
): { past?: JournalEntry; current?: JournalEntry } {
  const past = candidate.pastEntryId
    ? allSorted.find((entry) => entry.id === candidate.pastEntryId)
    : undefined;
  const current = candidate.entryId
    ? allSorted.find((entry) => entry.id === candidate.entryId)
    : undefined;
  return { past, current };
}

function contrastBoosts(
  candidate: KnowsMeCandidate,
  past: JournalEntry | undefined,
  current: JournalEntry | undefined,
): number {
  let boost = 0;

  if (SELF_CONTRAST_SIGNALS.has(candidate.signal)) boost += 10;
  if (candidate.signal === "topic_quieter") boost -= 8;

  if (candidate.pastQuote?.trim() && candidate.currentQuote?.trim()) boost += 12;

  if (past && current) {
    const intensityDrop = past.reflection.emotionalIntensity - current.reflection.emotionalIntensity;
    if (intensityDrop >= 1.2) {
      boost += 8 + Math.round(intensityDrop * 3);
    }

    const hedgeDrop = hedgeCount(past) - hedgeCount(current);
    if (hedgeDrop >= 1) boost += 6 + hedgeDrop * 2;

    const directGain = directCount(current) - directCount(past);
    if (directGain >= 1) boost += 6 + directGain * 2;

    const gap = daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
    if (gap >= 14) boost += Math.min(Math.round(gap / 7), 10);

    if (past.audioId) boost += 6;
    if (current.audioId) boost += 6;
  }

  switch (candidate.signal) {
    case "wording_shift":
      boost += 8;
      break;
    case "phrase_gone":
      boost += 10;
      break;
    case "direct_naming":
    case "directness_shift":
    case "certainty_shift":
      boost += 9;
      break;
    default:
      break;
  }

  if (isTopicRecurrenceCopy(candidate.text)) boost -= 28;

  return boost;
}

function adjustCandidateStrength(
  candidate: KnowsMeCandidate,
  allSorted: JournalEntry[],
): KnowsMeCandidate {
  const { past, current } = entriesForCandidate(candidate, allSorted);
  const strength = candidate.strength + contrastBoosts(candidate, past, current);
  return { ...candidate, strength: Math.max(0, strength) };
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function evidence(past: JournalEntry, current: JournalEntry) {
  return fingerprintEvidence(past, current);
}

function fingerprintFromPrior(prior: JournalEntry[]): LanguageFingerprint | null {
  if (prior.length < MIN_FINGERPRINT_ENTRIES) return null;
  return buildLanguageFingerprint(prior);
}

function sharedThemes(a: JournalEntry, b: JournalEntry): string[] {
  const setB = new Set(b.reflection.recurringThemes.map((t) => t.toLowerCase()));
  return a.reflection.recurringThemes.filter((t) => setB.has(t.toLowerCase()));
}

function pushCandidate(
  bucket: KnowsMeCandidate[],
  item: Omit<KnowsMeCandidate, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (!helpsOrient(item.text, strength)) return;
  bucket.push({ ...item, strength });
}

function detectEmotionalContrast(
  anchor: JournalEntry,
  compare: JournalEntry,
  fingerprint: LanguageFingerprint | null,
): KnowsMeCandidate | null {
  const overlap = sharedThemes(anchor, compare);
  if (overlap.length === 0) return null;

  const intensityDelta = Math.abs(
    anchor.reflection.emotionalIntensity - compare.reflection.emotionalIntensity,
  );
  if (intensityDelta < 2) return null;

  const anchorIsHeavier = anchor.reflection.emotionalIntensity > compare.reflection.emotionalIntensity;
  const gap = daysBetweenKeys(
    toDayKey(anchorIsHeavier ? compare.createdAt : anchor.createdAt),
    toDayKey(anchorIsHeavier ? anchor.createdAt : compare.createdAt),
  );

  const past = anchorIsHeavier ? compare : anchor;
  const current = anchorIsHeavier ? anchor : compare;

  const settledNow =
    fingerprint &&
    current.reflection.emotionalIntensity <= fingerprint.intensityP25 - 0.3;

  return {
    id: `knows-me-contrast-${past.id}-${current.id}`,
    signal: "emotional_contrast",
    text: anchorIsHeavier
      ? KNOWS_ME_COPY.used_to_feel_heavier
      : settledNow
        ? KNOWS_ME_COPY.sound_more_direct
        : KNOWS_ME_COPY.earlier_version,
    strength: 64 + Math.round(intensityDelta * 4) + Math.min(gap, 10) + overlap.length * 2,
    ...evidence(past, current),
  };
}

function detectWeightShift(
  anchor: JournalEntry,
  allSorted: JournalEntry[],
  fingerprint: LanguageFingerprint | null,
): KnowsMeCandidate | null {
  for (const theme of anchor.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const trend = getThemeIntensityTrend(allSorted, themeKey);
    if (!trend || trend.peakEntry.id === anchor.id) continue;
    if (trend.delta < 2) continue;
    if (!hasTheme(anchor, themeKey) && anchor.id !== allSorted[allSorted.length - 1].id) {
      continue;
    }

    const latest = allSorted[allSorted.length - 1];
    const past = trend.peakEntry;
    const current = anchor.id === latest.id ? latest : anchor;

    if (past.id === current.id) continue;
    if (
      fingerprint &&
      past.reflection.emotionalIntensity < fingerprint.intensityP75 &&
      trend.delta < 2.5
    ) {
      continue;
    }

    return {
      id: `knows-me-weight-${themeKey}-${past.id}`,
      signal: "weight_shift",
      text: KNOWS_ME_COPY.used_to_feel_heavier,
      strength: 66 + Math.round(trend.delta * 5) + trend.mentions * 2,
      ...evidence(past, current),
    };
  }
  return null;
}

function detectTopicQuieter(
  anchor: JournalEntry,
  prior: JournalEntry[],
  fingerprint: LanguageFingerprint | null,
): KnowsMeCandidate | null {
  const quietThreshold = fingerprint?.intensityP25 ?? 4.5;
  if (anchor.reflection.emotionalIntensity > quietThreshold + 0.5) return null;

  for (const theme of anchor.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const intense = [...prior]
      .reverse()
      .find(
        (e) =>
          hasTheme(e, themeKey) &&
          e.reflection.emotionalIntensity >= (fingerprint?.intensityP75 ?? 6.5),
      );
    if (!intense) continue;
    if (anchor.reflection.emotionalIntensity > intense.reflection.emotionalIntensity - 1.5) {
      continue;
    }

    return {
      id: `knows-me-quieter-${intense.id}-${anchor.id}`,
      signal: "topic_quieter",
      text: KNOWS_ME_COPY.used_to_feel_heavier,
      strength:
        58 +
        Math.round(intense.reflection.emotionalIntensity - anchor.reflection.emotionalIntensity) *
          4,
      ...evidence(intense, anchor),
    };
  }
  return null;
}

function detectCertaintyAndDirectness(
  anchor: JournalEntry,
  prior: JournalEntry[],
  fingerprint: LanguageFingerprint | null,
): KnowsMeCandidate[] {
  const notes: KnowsMeCandidate[] = [];
  if (!fingerprint) return notes;

  for (const theme of anchor.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const priorMatches = prior.filter((e) => hasTheme(e, themeKey));
    if (priorMatches.length === 0) continue;

    const lastPrior = priorMatches[priorMatches.length - 1];
    const shift = languageShiftOnTheme(lastPrior, anchor);
    const ev = evidence(lastPrior, anchor);
    const gap = daysBetweenKeys(toDayKey(lastPrior.createdAt), toDayKey(anchor.createdAt));

    const priorHedged = hedgeCount(lastPrior) >= Math.max(fingerprint.avgHedge, 2);
    const nowDirect = directCount(anchor) >= fingerprint.avgDirect + 1;

    if (priorHedged && nowDirect && shift.directDelta >= 1) {
      pushCandidate(notes, {
        id: `knows-me-named-${themeKey}-${anchor.id}`,
        signal: "direct_naming",
        text: KNOWS_ME_COPY.sound_more_direct,
        strength: 68 + shift.directDelta * 4 + Math.min(gap, 8),
        ...ev,
      });
    }

    if (shift.hedgeDelta >= 2 && shift.directDelta >= 1) {
      pushCandidate(notes, {
        id: `knows-me-certainty-${themeKey}-${anchor.id}`,
        signal: "certainty_shift",
        text: KNOWS_ME_COPY.sound_more_direct,
        strength: 64 + shift.hedgeDelta * 3 + shift.directDelta * 2,
        ...ev,
      });
    }

    if (directCount(anchor) >= fingerprint.avgDirect + 1.5 && shift.directDelta >= 2) {
      pushCandidate(notes, {
        id: `knows-me-direct-${themeKey}-${anchor.id}`,
        signal: "directness_shift",
        text: KNOWS_ME_COPY.sound_more_direct,
        strength: 62 + shift.directDelta * 4,
        ...ev,
      });
    }
  }

  return notes;
}

function detectStoppedCircling(
  anchor: JournalEntry,
  prior: JournalEntry[],
  sorted: JournalEntry[],
  anchorIdx: number,
  fingerprint: LanguageFingerprint | null,
): KnowsMeCandidate | null {
  if (!fingerprint) return null;

  for (const theme of anchor.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const typical = fingerprint.themeCircleRun.get(themeKey);
    if (!typical || typical < 2.5) continue;

    const run = currentCircleRun(sorted, anchorIdx, themeKey);
    if (run >= typical - 0.5) continue;

    const circlingPrior = [...prior]
      .reverse()
      .find((e) => hasTheme(e, themeKey) && isLooping(e));
    if (!circlingPrior) continue;

    const gap = daysBetweenKeys(toDayKey(circlingPrior.createdAt), toDayKey(anchor.createdAt));
    if (gap < 7) continue;

    return {
      id: `knows-me-circling-${themeKey}-${circlingPrior.id}`,
      signal: "phrase_gone",
      text: FAMILIARITY_COPY.stoppedCircling,
      strength: 65 + Math.min(gap, 12) + Math.round((typical - run) * 3),
      ...evidence(circlingPrior, anchor),
    };
  }
  return null;
}

function detectPhraseStopped(allSorted: JournalEntry[]): KnowsMeCandidate | null {
  const today = toDayKey(new Date().toISOString());
  const cutoff = addDaysToKey(today, -ABSENCE_DAYS);
  const latest = allSorted[allSorted.length - 1];
  const phrases = buildPhraseMemory(allSorted);

  for (const record of phrases) {
    if (record.count < 3) continue;
    const lastOcc = record.occurrences[record.occurrences.length - 1];
    if (lastOcc.dateKey >= cutoff) continue;

    const gap = daysBetweenKeys(lastOcc.dateKey, today);
    if (gap < ABSENCE_DAYS) continue;

    const priorEntry = allSorted.find((e) => e.id === lastOcc.entryId);
    if (!priorEntry) continue;

    return {
      id: `knows-me-phrase-gone-${record.phrase}`,
      signal: "phrase_gone",
      text: FAMILIARITY_COPY.stoppedCircling,
      strength: 64 + Math.min(record.count, 5) + Math.min(gap, 10),
      ...evidence(priorEntry, latest),
    };
  }
  return null;
}

function detectEarlierSelf(
  anchor: JournalEntry,
  prior: JournalEntry[],
  later: JournalEntry[],
  fingerprint: LanguageFingerprint | null,
): KnowsMeCandidate | null {
  const comparePool = [...prior, ...later];
  if (comparePool.length === 0) return null;

  const latest = [...prior, anchor, ...later].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  ).at(-1);
  if (!latest || latest.id === anchor.id) return null;

  const overlap = sharedThemes(anchor, latest);
  if (overlap.length === 0) return null;

  const gap = daysBetweenKeys(toDayKey(anchor.createdAt), toDayKey(latest.createdAt));
  if (gap < ABSENCE_DAYS) return null;

  const anchorHedged = hedgeCount(anchor) >= Math.max(fingerprint?.avgHedge ?? 2, 2);
  const anchorIntense =
    anchor.reflection.emotionalIntensity >= (fingerprint?.intensityP75 ?? 6);
  const latestCalmer = latest.reflection.emotionalIntensity <= anchor.reflection.emotionalIntensity - 1.5;
  const latestDirecter = directCount(latest) > directCount(anchor);

  if (!anchorHedged && !anchorIntense && !latestCalmer && !latestDirecter) return null;

  const past = anchor;
  const current = latest;

  return {
    id: `knows-me-earlier-${anchor.id}`,
    signal: "earlier_self",
    text: KNOWS_ME_COPY.earlier_version,
    strength:
      67 +
      Math.min(gap, 14) +
      (anchorIntense ? 4 : 0) +
      (anchorHedged ? 3 : 0) +
      overlap.length * 2,
    ...evidence(past, current),
  };
}

function detectWordingShift(
  anchor: JournalEntry,
  prior: JournalEntry[],
  fingerprint: LanguageFingerprint | null,
): KnowsMeCandidate | null {
  for (let i = prior.length - 1; i >= 0; i -= 1) {
    const old = prior[i];
    const gap = daysBetweenKeys(toDayKey(old.createdAt), toDayKey(anchor.createdAt));
    if (gap < ABSENCE_DAYS) continue;

    const overlap = sharedThemes(anchor, old);
    if (overlap.length === 0) continue;

    const intensityDelta = Math.abs(
      anchor.reflection.emotionalIntensity - old.reflection.emotionalIntensity,
    );
    const hedgeFlip =
      hedgeCount(old) >= Math.max(fingerprint?.avgHedge ?? 2, 2) &&
      hedgeCount(anchor) <= Math.max((fingerprint?.avgHedge ?? 2) - 1, 1);

    if (intensityDelta < 1.5 && !hedgeFlip) continue;

    return {
      id: `knows-me-wording-${old.id}-${anchor.id}`,
      signal: "wording_shift",
      text: hedgeFlip ? KNOWS_ME_COPY.sound_more_direct : KNOWS_ME_COPY.earlier_version,
      strength: 60 + Math.min(gap, 12) + overlap.length * 3 + (hedgeFlip ? 6 : 0),
      ...evidence(old, anchor),
    };
  }
  return null;
}

function detectStillCirclingHere(
  anchor: JournalEntry,
  later: JournalEntry[],
  sorted: JournalEntry[],
  anchorIdx: number,
  fingerprint: LanguageFingerprint | null,
): KnowsMeCandidate | null {
  if (!fingerprint) return null;

  for (const theme of anchor.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const typical = fingerprint.themeCircleRun.get(themeKey);
    if (!typical || typical < 2) continue;

    const run = currentCircleRun(sorted, anchorIdx, themeKey);
    if (run < typical - 0.25 && !isLooping(anchor)) continue;

    const calmerLater = later.find(
      (entry) =>
        hasTheme(entry, themeKey) &&
        entry.reflection.emotionalIntensity <= anchor.reflection.emotionalIntensity - 1.2,
    );
    if (!calmerLater && later.length > 0) continue;

    const compare = calmerLater ?? later[later.length - 1];
    if (!compare || compare.id === anchor.id) continue;

    const gap = daysBetweenKeys(toDayKey(anchor.createdAt), toDayKey(compare.createdAt));
    if (gap < 7) continue;

    return {
      id: `knows-me-still-circling-${themeKey}-${anchor.id}`,
      signal: "earlier_self",
      text: KNOWS_ME_COPY.still_circling,
      strength: 66 + Math.min(gap, 12) + Math.round(run),
      ...evidence(anchor, compare),
    };
  }

  return null;
}

function detectApologyShift(
  anchor: JournalEntry,
  allSorted: JournalEntry[],
): KnowsMeCandidate | null {
  const latest = allSorted[allSorted.length - 1];
  if (anchor.id === latest.id) return null;

  const overlap = sharedThemes(anchor, latest);
  if (overlap.length === 0) return null;

  const gap = daysBetweenKeys(toDayKey(anchor.createdAt), toDayKey(latest.createdAt));
  if (gap < ABSENCE_DAYS) return null;

  const hadApology = apologyCount(anchor) >= 1;
  const stoppedApologising = apologyCount(latest) === 0;
  const hedgeDrop = hedgeCount(anchor) - hedgeCount(latest) >= 1;

  if (!hadApology || !stoppedApologising) return null;
  if (!hedgeDrop && apologyCount(anchor) < 2) return null;

  return {
    id: `knows-me-apology-${anchor.id}-${latest.id}`,
    signal: "wording_shift",
    text: KNOWS_ME_COPY.stopped_apologising,
    strength: 68 + Math.min(gap, 12) + apologyCount(anchor) * 2 + (hedgeDrop ? 4 : 0),
    ...evidence(anchor, latest),
  };
}

function detectReopenedBeforeQuieter(
  anchor: JournalEntry,
  later: JournalEntry[],
  fingerprint: LanguageFingerprint | null,
): KnowsMeCandidate | null {
  const heavyThreshold = fingerprint?.intensityP75 ?? 6;
  if (anchor.reflection.emotionalIntensity < heavyThreshold || later.length === 0) return null;

  for (const theme of anchor.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const calmerLater = later.find(
      (entry) =>
        hasTheme(entry, themeKey) && entry.reflection.emotionalIntensity <= 4.5,
    );
    if (!calmerLater) continue;

    return {
      id: `knows-me-reopen-quiet-${anchor.id}-${calmerLater.id}`,
      signal: "topic_quieter",
      text: REVISIT_REWARD_COPY.soundFurtherAway,
      strength:
        70 +
        Math.round(anchor.reflection.emotionalIntensity - calmerLater.reflection.emotionalIntensity) *
          4,
      ...evidence(anchor, calmerLater),
    };
  }

  return null;
}

function collectCandidates(
  entries: JournalEntry[],
  anchor: JournalEntry,
  prior: JournalEntry[],
  later: JournalEntry[],
  allSorted: JournalEntry[],
): KnowsMeCandidate[] {
  const notes: KnowsMeCandidate[] = [];
  const latest = allSorted[allSorted.length - 1];
  const anchorIdx = allSorted.findIndex((e) => e.id === anchor.id);
  const fingerprint = fingerprintFromPrior(prior);

  const reopenedBeforeQuieter = detectReopenedBeforeQuieter(anchor, later, fingerprint);
  if (reopenedBeforeQuieter) notes.push(reopenedBeforeQuieter);

  const stillCircling = detectStillCirclingHere(anchor, later, allSorted, anchorIdx, fingerprint);
  if (stillCircling) notes.push(stillCircling);

  const apologyShift = detectApologyShift(anchor, allSorted);
  if (apologyShift) notes.push(apologyShift);

  const earlier = detectEarlierSelf(anchor, prior, later, fingerprint);
  if (earlier) notes.push(earlier);

  const quieter = detectTopicQuieter(anchor, prior, fingerprint);
  if (quieter) notes.push(quieter);

  const weight = detectWeightShift(anchor, allSorted, fingerprint);
  if (weight) notes.push(weight);

  notes.push(...detectCertaintyAndDirectness(anchor, prior, fingerprint));

  const stopped = detectStoppedCircling(anchor, prior, allSorted, anchorIdx, fingerprint);
  if (stopped) notes.push(stopped);

  const wording = detectWordingShift(anchor, prior, fingerprint);
  if (wording) notes.push(wording);

  const contrastWithLatest =
    anchor.id !== latest.id ? detectEmotionalContrast(anchor, latest, fingerprint) : null;
  if (contrastWithLatest) notes.push(contrastWithLatest);

  for (const old of prior.slice(-6)) {
    const contrast = detectEmotionalContrast(anchor, old, fingerprint);
    if (contrast) notes.push(contrast);
  }

  if (anchor.id === latest.id) {
    const phraseGone = detectPhraseStopped(allSorted);
    if (phraseGone) notes.push(phraseGone);
  }

  return notes;
}

function pickBest(
  candidates: KnowsMeCandidate[],
  minStrength: number,
  allSorted: JournalEntry[],
): KnowsMeCandidate | null {
  const eligible = candidates
    .map((candidate) => adjustCandidateStrength(candidate, allSorted))
    .filter((candidate) => candidate.strength >= minStrength)
    .filter((candidate) => !isTopicRecurrenceCopy(candidate.text));

  if (eligible.length === 0) return null;

  const sorted = [...eligible].sort((a, b) => {
    const aPri = SIGNAL_PRIORITY.indexOf(a.signal);
    const bPri = SIGNAL_PRIORITY.indexOf(b.signal);
    if (aPri !== bPri) return aPri - bPri;
    return b.strength - a.strength;
  });

  const seen = new Set<string>();
  for (const note of sorted) {
    const key = note.text.slice(0, 40);
    if (seen.has(key)) continue;
    seen.add(key);
    return note;
  }
  return null;
}

function toMemoryNote(candidate: KnowsMeCandidate): MemoryNote {
  return {
    id: candidate.id,
    text: candidate.text,
    category: "changed",
    confidence: candidate.strength,
    pastQuote: candidate.pastQuote,
    currentQuote: candidate.currentQuote,
    pastDateLabel: candidate.pastDateLabel,
    currentDateLabel: candidate.currentDateLabel,
    pastEntryId: candidate.pastEntryId,
    entryId: candidate.entryId,
  };
}

function revisitTextForSignal(signal: KnowsMeSignal, fallback: string): string {
  switch (signal) {
    case "topic_quieter":
      return REVISIT_REWARD_COPY.soundFurtherAway;
    case "certainty_shift":
    case "direct_naming":
      return REVISIT_REWARD_COPY.notNamedYet;
    case "weight_shift":
      return REVISIT_REWARD_COPY.usedToTakeSpace;
    case "phrase_gone":
      return REVISIT_REWARD_COPY.usedToTakeSpace;
    case "emotional_contrast":
    case "wording_shift":
    case "directness_shift":
    case "earlier_self":
      return REVISIT_REWARD_COPY.soundDifferentNow;
    default:
      return fallback;
  }
}

function toRevisitMemoryNote(candidate: KnowsMeCandidate): MemoryNote {
  return {
    ...toMemoryNote(candidate),
    text: revisitTextForSignal(candidate.signal, candidate.text),
  };
}

function hasContrastEvidence(note: MemoryNote): boolean {
  return Boolean(note.pastQuote?.trim() && note.currentQuote?.trim());
}

function signalFromNoteId(note: MemoryNote): KnowsMeSignal | null {
  if (note.id.startsWith("knows-me-contrast")) return "emotional_contrast";
  if (note.id.startsWith("knows-me-weight")) return "weight_shift";
  if (note.id.startsWith("knows-me-wording") || note.id.startsWith("knows-me-apology")) {
    return "wording_shift";
  }
  if (note.id.startsWith("knows-me-quieter")) return "topic_quieter";
  if (note.id.startsWith("knows-me-named") || note.id.startsWith("knows-me-certainty")) {
    return "certainty_shift";
  }
  if (note.id.startsWith("knows-me-direct")) return "directness_shift";
  if (note.id.startsWith("knows-me-earlier") || note.id.startsWith("knows-me-still-circling")) {
    return "earlier_self";
  }
  if (note.id.startsWith("revisit-before-quiet")) return "topic_quieter";
  if (note.id.startsWith("change-charged")) return "weight_shift";
  if (note.id.startsWith("tvn-") || note.id.startsWith("revisit-diff")) return "emotional_contrast";
  return null;
}

function revisitPriority(note: MemoryNote, order: KnowsMeSignal[]): number {
  const signal = signalFromNoteId(note);
  if (!signal) return order.length + 1;
  const index = order.indexOf(signal);
  return index >= 0 ? index : order.length;
}

function isDuplicateRevisitNote(a: MemoryNote, b: MemoryNote | null | undefined): boolean {
  if (!b) return false;
  return a.id === b.id || a.text === b.text;
}

/** All revisit-reward candidates for an entry anchor — internal ranking pool. */
export function entryRevisitRewardCandidates(
  entries: JournalEntry[],
  entryId: string,
): MemoryNote[] {
  const allSorted = sortedEntries(entries);
  const resolved = resolveAnchor(allSorted, "entry", entryId);
  if (!resolved) return [];

  return collectCandidates(
    entries,
    resolved.anchor,
    resolved.prior,
    resolved.later,
    allSorted,
  ).map(toRevisitMemoryNote);
}

/** Strongest before/after contrast for a revisit — quotes required and quality-filtered. */
export function pickEntryRevisitContrast(
  candidates: MemoryNote[],
  extra: MemoryNote[],
  exclude: Array<MemoryNote | null | undefined>,
  entries: JournalEntry[],
): MemoryNote | null {
  const pool = [...candidates, ...extra]
    .filter((note) => hasContrastEvidence(note))
    .filter((note) => !exclude.some((row) => isDuplicateRevisitNote(note, row)))
    .sort(
      (a, b) =>
        revisitPriority(a, REVISIT_CONTRAST_PRIORITY) -
          revisitPriority(b, REVISIT_CONTRAST_PRIORITY) ||
        b.confidence - a.confidence,
    );

  const ranked = rankReopenPayoffNotes(
    filterFalsePositiveNotes(pool, entries, "revisit_reward"),
    entries,
  );
  return ranked[0] ?? null;
}

/** Single reward line when contrast alone is not enough — text-first moments. */
export function pickEntryRevisitRewardLine(
  candidates: MemoryNote[],
  exclude: Array<MemoryNote | null | undefined>,
  entries: JournalEntry[] = [],
): MemoryNote | null {
  const pool = filterFalsePositiveNotes(
    candidates
      .filter((note) => !exclude.some((row) => isDuplicateRevisitNote(note, row)))
      .sort(
        (a, b) =>
          revisitPriority(a, REVISIT_REWARD_LINE_PRIORITY) -
            revisitPriority(b, REVISIT_REWARD_LINE_PRIORITY) ||
          b.confidence - a.confidence,
      ),
    entries,
    "revisit_reward",
  );

  return pool[0] ?? null;
}

function resolveAnchor(
  allSorted: JournalEntry[],
  surface: KnowsMeSurface,
  entryId?: string,
): { anchor: JournalEntry; prior: JournalEntry[]; later: JournalEntry[] } | null {
  if (allSorted.length < 3) return null;

  if (surface === "entry" && entryId) {
    const idx = allSorted.findIndex((e) => e.id === entryId);
    if (idx < 0) return null;
    return {
      anchor: allSorted[idx],
      prior: allSorted.slice(0, idx),
      later: allSorted.slice(idx + 1),
    };
  }

  const anchor = allSorted[allSorted.length - 1];
  return {
    anchor,
    prior: allSorted.slice(0, -1),
    later: [],
  };
}

/** Detect and rank a single knows-me moment for a surface. */
export function pickKnowsMeMoment(
  entries: JournalEntry[],
  options: {
    surface: KnowsMeSurface;
    entryId?: string;
    minStrength?: number;
  },
): MemoryNote | null {
  const allSorted = sortedEntries(entries);
  const resolved = resolveAnchor(allSorted, options.surface, options.entryId);
  if (!resolved) return null;

  const minStrength =
    options.minStrength ??
    (options.surface === "entry" ? KNOWS_ME_VISIT_MIN : KNOWS_ME_SURFACE_MIN);

  const candidates = collectCandidates(
    entries,
    resolved.anchor,
    resolved.prior,
    resolved.later,
    allSorted,
  );
  const best = pickBest(candidates, minStrength, allSorted);
  if (!best) return null;
  return guardSurfacedNote(
    gateDelayedPayoffNote(allSorted, toMemoryNote(best)),
    allSorted,
    "knows_me",
  );
}

export function entryKnowsMeMoment(
  entries: JournalEntry[],
  entryId: string,
): MemoryNote | null {
  return pickKnowsMeMoment(entries, {
    surface: "entry",
    entryId,
    minStrength: KNOWS_ME_VISIT_MIN,
  });
}

export function homepageKnowsMeMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickKnowsMeMoment(entries, {
    surface: "homepage",
    minStrength: KNOWS_ME_SURFACE_MIN,
  });
}

export function timelineKnowsMeMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickKnowsMeMoment(entries, {
    surface: "timeline",
    minStrength: KNOWS_ME_SURFACE_MIN,
  });
}

export function monthlyKnowsMeMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickKnowsMeMoment(entries, {
    surface: "monthly",
    minStrength: KNOWS_ME_SURFACE_MIN,
  });
}
