import { addDaysToKey, daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { filterOrienting, pickStrongest, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import { formatEntryDate } from "@/lib/utils";
import type {
  ContinuityCallback,
  ContinuityCallbackKind,
  ContinuityContext,
  ContinuityMoment,
  ContinuityMomentKind,
  ContinuityMomentsReport,
  ThenVsNowComparison,
} from "@/types/continuity-moments";
import type { JournalEntry } from "@/types/journal";

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|i don't know|eventually)\b/gi;
const DIRECT_RE =
  /\b(i will|i know|decided|clearly|named|wrote down|for sure|definitely)\b/gi;
const VAGUE_RE =
  /\b(family pressure|that thing|stuff|something|kind of|sort of|indirectly)\b/gi;
const ABSENCE_DAYS = 7;

export interface ContinuityMomentsOptions {
  context?: ContinuityContext;
  entryId?: string;
  callbackLimit?: number;
  landmarkLimit?: number;
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function filterContext(entries: JournalEntry[], context: ContinuityContext): JournalEntry[] {
  if (context === "memory" || context === "timeline" || context === "entry") return entries;
  const days = context === "weekly" ? 7 : 30;
  const cutoff = addDaysToKey(toDayKey(new Date().toISOString()), -(days - 1));
  return entries.filter((e) => toDayKey(e.createdAt) >= cutoff);
}

function snippet(entry: JournalEntry): string {
  return (
    entry.reflection.exactLanguagePattern?.trim() ||
    entry.reflection.concreteObservation?.trim() ||
    entry.transcript.slice(0, 160)
  );
}

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function monthName(dayKey: string): string {
  const [y, m] = dayKey.split("-").map(Number);
  return new Intl.DateTimeFormat("en-US", { month: "long" }).format(new Date(y, m - 1, 1));
}

function pushCallback(
  bucket: ContinuityCallback[],
  item: Omit<ContinuityCallback, "confidence"> & { confidence?: number },
): void {
  const confidence = item.confidence ?? 55;
  if (!filterOrienting([{ ...item, confidence }], (c) => c.text).length) return;
  bucket.push({ ...item, confidence });
}

function pushMoment(
  bucket: ContinuityMoment[],
  item: Omit<ContinuityMoment, "confidence"> & { confidence?: number },
): void {
  const confidence = item.confidence ?? 55;
  if (confidence < USEFULNESS_MIN_CONFIDENCE) return;
  bucket.push({ ...item, confidence });
}

function sharedThemes(a: JournalEntry, b: JournalEntry): string[] {
  const setB = new Set(b.reflection.recurringThemes.map((t) => t.toLowerCase()));
  return a.reflection.recurringThemes.filter((t) => setB.has(t.toLowerCase()));
}

function entriesForEntryContext(
  sorted: JournalEntry[],
  entryId: string,
): { current: JournalEntry; prior: JournalEntry[] } | null {
  const idx = sorted.findIndex((e) => e.id === entryId);
  if (idx < 0) return null;
  return { current: sorted[idx], prior: sorted.slice(0, idx) };
}

function detectEntryCallbacks(
  sorted: JournalEntry[],
  entryId: string,
): ContinuityCallback[] {
  const ctx = entriesForEntryContext(sorted, entryId);
  if (!ctx || ctx.prior.length === 0) return [];

  const { current, prior } = ctx;
  const callbacks: ContinuityCallback[] = [];

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const priorTheme = prior.filter((e) =>
      e.reflection.recurringThemes.some((t) => t.toLowerCase() === themeKey),
    );
    if (priorTheme.length === 0) continue;

    const priorAvg = roundAvg(priorTheme.map((e) => e.reflection.emotionalIntensity));
    const delta = priorAvg - current.reflection.emotionalIntensity;

    if (delta >= 1.5) {
      pushCallback(callbacks, {
        id: `cb-calmer-${themeKey}-${entryId}`,
        text: "This sounds lighter than before.",
        kind: "sounds_calmer",
        confidence: 60 + Math.round(delta * 4),
        entryIds: [...priorTheme.slice(-2).map((e) => e.id), current.id],
        anchorEntryId: entryId,
      });
    } else if (Math.abs(delta) >= 2 || priorTheme[priorTheme.length - 1].reflection.mood !== current.reflection.mood) {
      pushCallback(callbacks, {
        id: `cb-different-${themeKey}-${entryId}`,
        text: "This came up differently before.",
        kind: "came_up_differently",
        confidence: 58 + Math.round(Math.abs(delta) * 3),
        entryIds: [priorTheme[priorTheme.length - 1].id, current.id],
        anchorEntryId: entryId,
      });
    }

    const priorHedge = roundAvg(priorTheme.map((e) => countMatches(e.transcript, HEDGE_RE)));
    const nowHedge = countMatches(current.transcript, HEDGE_RE);
    const nowDirect = countMatches(current.transcript, DIRECT_RE);
    const priorDirect = roundAvg(priorTheme.map((e) => countMatches(e.transcript, DIRECT_RE)));

    if (priorHedge >= 1 && nowHedge < priorHedge && nowDirect > priorDirect) {
      pushCallback(callbacks, {
        id: `cb-vague-${themeKey}-${entryId}`,
        text: "You used to describe this more vaguely.",
        kind: "used_to_be_vague",
        confidence: 62,
        entryIds: [priorTheme[priorTheme.length - 1].id, current.id],
        anchorEntryId: entryId,
      });
    }
  }

  if (countMatches(current.transcript, DIRECT_RE) > 0) {
    for (const theme of current.reflection.recurringThemes) {
      const themeKey = theme.toLowerCase();
      const priorDirectOnTheme = prior.filter(
        (e) =>
          e.reflection.recurringThemes.some((t) => t.toLowerCase() === themeKey) &&
          DIRECT_RE.test(e.transcript),
      );
      if (priorDirectOnTheme.length === 0 && prior.some((e) => e.reflection.recurringThemes.some((t) => t.toLowerCase() === themeKey))) {
        pushCallback(callbacks, {
          id: `cb-first-direct-${themeKey}-${entryId}`,
          text: "You named this directly this time.",
          kind: "first_direct",
          confidence: 64,
          entryIds: [current.id],
          anchorEntryId: entryId,
        });
        break;
      }
    }
  }

  const thirtyDaysAgo = addDaysToKey(toDayKey(current.createdAt), -30);
  const monthPrior = prior.filter((e) => toDayKey(e.createdAt) >= thirtyDaysAgo);
  if (monthPrior.length >= 2) {
    const monthAvg = roundAvg(monthPrior.map((e) => e.reflection.emotionalIntensity));
    if (monthAvg - current.reflection.emotionalIntensity >= 1.2) {
      pushCallback(callbacks, {
        id: `cb-calmer-month-${entryId}`,
        text: "This sounds lighter than before.",
        kind: "sounds_calmer",
        confidence: 61,
        entryIds: [...monthPrior.slice(-2).map((e) => e.id), current.id],
        anchorEntryId: entryId,
      });
    }
  }

  return callbacks;
}

function detectArchiveCallbacks(
  sorted: JournalEntry[],
  context: ContinuityContext,
): ContinuityCallback[] {
  const callbacks: ContinuityCallback[] = [];
  const scoped = filterContext(sorted, context);
  if (scoped.length < 3) return [];

  const phrases = buildPhraseMemory(sorted);
  for (const phrase of phrases.filter((p) => p.count >= 3)) {
    const last = phrase.occurrences[phrase.occurrences.length - 1];
    const daysSince = daysBetweenKeys(last.dateKey, toDayKey(new Date().toISOString()));
    if (daysSince >= ABSENCE_DAYS) {
      const month = monthName(last.dateKey);
      pushCallback(callbacks, {
        id: `cb-phrase-stopped-${phrase.phrase}`,
        text: `This has not appeared for a while.`,
        kind: "topic_stopped",
        confidence: 60 + phrase.count,
        entryIds: phrase.entryIds,
      });
    }
  }

  const themeMap = new Map<string, JournalEntry[]>();
  for (const entry of sorted) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase();
      themeMap.set(key, [...(themeMap.get(key) ?? []), entry]);
    }
  }

  for (const [theme, group] of themeMap.entries()) {
    if (group.length < 4) continue;
    const mid = Math.floor(group.length / 2);
    const early = group.slice(0, mid);
    const late = group.slice(mid);
    const earlyAvg = roundAvg(early.map((e) => e.reflection.emotionalIntensity));
    const lateAvg = roundAvg(late.map((e) => e.reflection.emotionalIntensity));
    if (lateAvg <= earlyAvg - 1.2) {
      pushCallback(callbacks, {
        id: `cb-theme-calmer-${theme}`,
        text: "This used to come with more tension.",
        kind: "sounds_different",
        confidence: 59 + Math.round((earlyAvg - lateAvg) * 4),
        entryIds: [...early.slice(-1), ...late.slice(0, 1)].map((e) => e.id),
      });
    }

    const last = group[group.length - 1];
    const daysSince = daysBetweenKeys(toDayKey(last.createdAt), toDayKey(new Date().toISOString()));
    if (daysSince >= ABSENCE_DAYS + 3 && scoped.some((e) => e.id === last.id)) {
      pushCallback(callbacks, {
        id: `cb-topic-stopped-${theme}`,
        text: "This has not appeared for a while.",
        kind: "topic_stopped",
        confidence: 58,
        entryIds: group.map((e) => e.id),
      });
    }
  }

  return callbacks;
}

function detectMoments(sorted: JournalEntry[]): ContinuityMoment[] {
  const moments: ContinuityMoment[] = [];
  const phrases = buildPhraseMemory(sorted);

  for (const phrase of phrases.filter((p) => p.count >= 3)) {
    const last = phrase.occurrences[phrase.occurrences.length - 1];
    const daysSince = daysBetweenKeys(last.dateKey, toDayKey(new Date().toISOString()));
    if (daysSince >= ABSENCE_DAYS) {
      pushMoment(moments, {
        id: `moment-phrase-gone-${phrase.phrase}`,
        kind: "phrase_disappearance",
        text: `You stopped saying "${phrase.phrase}".`,
        detail: `Last on ${last.dateLabel}.`,
        confidence: 60 + phrase.count,
        entryIds: phrase.entryIds,
        dateLabel: last.dateLabel,
      });
    }
  }

  const themeMap = new Map<string, Array<{ entry: JournalEntry; intensity: number }>>();
  for (const entry of sorted) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase();
      const list = themeMap.get(key) ?? [];
      list.push({ entry, intensity: entry.reflection.emotionalIntensity });
      themeMap.set(key, list);
    }
  }

  for (const [theme, rows] of themeMap.entries()) {
    if (rows.length < 3) continue;

    const peak = rows.reduce((best, r) => (r.intensity > best.intensity ? r : best));
    if (peak.intensity >= 6 && /work|pressure|deadline/.test(theme)) {
      pushMoment(moments, {
        id: `moment-peak-${theme}`,
        kind: "last_concern_appearance",
        text: "This was when work pressure peaked.",
        detail: `${peak.intensity}/10 on ${formatEntryDate(peak.entry.createdAt)}.`,
        confidence: 62 + peak.intensity,
        entryIds: [peak.entry.id],
        dateLabel: formatEntryDate(peak.entry.createdAt),
      });
    }

    const calmRows = rows.filter((r) => r.intensity <= 4 && /money|calm|grounded|relieved/.test(r.entry.reflection.mood));
    const moneyTheme = theme.includes("money");
    if (moneyTheme && calmRows.length > 0) {
      const first = calmRows[0];
      const priorMoney = rows.filter((r) => new Date(r.entry.createdAt) < new Date(first.entry.createdAt));
      if (priorMoney.some((r) => r.intensity >= 6)) {
        pushMoment(moments, {
          id: "moment-money-calm",
          kind: "first_calmer_mention",
          text: "This was the first calmer conversation about money.",
          detail: formatEntryDate(first.entry.createdAt),
          confidence: 64,
          entryIds: [first.entry.id],
          dateLabel: formatEntryDate(first.entry.createdAt),
        });
      }
    }

    const intensities = rows.map((r) => r.intensity);
    const peakIdx = intensities.indexOf(Math.max(...intensities));
    const afterPeak = rows.slice(peakIdx + 1);
    if (
      peakIdx > 0 &&
      afterPeak.length >= 2 &&
      afterPeak.every((r) => r.intensity <= intensities[peakIdx] - 1.5)
    ) {
      pushMoment(moments, {
        id: `moment-recovery-${theme}`,
        kind: "recovery_after_spike",
        text: "After a spike, the next entries read calmer.",
        detail: `Peak ${intensities[peakIdx]}/10, then averaged ${roundAvg(afterPeak.map((r) => r.intensity))}/10.`,
        confidence: 63,
        entryIds: [rows[peakIdx].entry.id, ...afterPeak.slice(0, 2).map((r) => r.entry.id)],
      });
    }

    const mid = Math.floor(rows.length / 2);
    const early = rows.slice(0, mid);
    const late = rows.slice(mid);
    const earlyAvg = roundAvg(early.map((r) => r.intensity));
    const lateAvg = roundAvg(late.map((r) => r.intensity));
    if (lateAvg <= earlyAvg - 1.5 && lateAvg <= 4) {
      pushMoment(moments, {
        id: `moment-resolved-${theme}`,
        kind: "topic_resolved",
        text: "This settled — it reads quieter now.",
        confidence: 60,
        entryIds: rows.map((r) => r.entry.id),
      });
    }
  }

  for (let i = 1; i < sorted.length; i += 1) {
    const prev = sorted[i - 1];
    const curr = sorted[i];
    const gap = daysBetweenKeys(toDayKey(prev.createdAt), toDayKey(curr.createdAt));
    const shared = sharedThemes(prev, curr);
    if (gap >= ABSENCE_DAYS + 2 && shared.length > 0) {
      pushMoment(moments, {
        id: `moment-loop-${curr.id}`,
        kind: "loop_returning",
        text: "You came back to this loop.",
        confidence: 59,
        entryIds: [prev.id, curr.id],
        dateLabel: formatEntryDate(curr.createdAt),
      });
    }
  }

  const familyEntries = sorted.filter(
    (e) =>
      e.reflection.recurringThemes.some((t) => /family/i.test(t)) ||
      VAGUE_RE.test(e.transcript),
  );
  if (familyEntries.length >= 4) {
    const mid = Math.floor(familyEntries.length / 2);
    const earlyVague = familyEntries.slice(0, mid).some((e) => /family pressure|indirectly/i.test(e.transcript));
    const lateNamed = familyEntries.slice(mid).some((e) => /\b(mum|dad|mother|father)\b/i.test(e.transcript));
    if (earlyVague && lateNamed) {
      const pivot = familyEntries.find((e) => /\b(mum|dad)\b/i.test(e.transcript));
      pushMoment(moments, {
        id: "moment-family-direct",
        kind: "first_direct_mention",
        text: "You stopped describing family pressure indirectly here.",
        detail: pivot ? formatEntryDate(pivot.createdAt) : undefined,
        confidence: 65,
        entryIds: familyEntries.slice(mid).map((e) => e.id).slice(0, 3),
        dateLabel: pivot ? formatEntryDate(pivot.createdAt) : undefined,
      });
    }
  }

  return moments;
}

function detectThenVsNow(
  sorted: JournalEntry[],
  entryId: string,
): ThenVsNowComparison | undefined {
  const ctx = entriesForEntryContext(sorted, entryId);
  if (!ctx || ctx.prior.length === 0) return undefined;

  const { current, prior } = ctx;
  let best: ThenVsNowComparison | undefined;
  let bestScore = 0;

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const priorMatches = prior.filter((e) =>
      e.reflection.recurringThemes.some((t) => t.toLowerCase() === themeKey),
    );
    if (priorMatches.length === 0) continue;

    const thenEntry = priorMatches[priorMatches.length - 1];
    const thenSnippet = snippet(thenEntry);
    const nowSnippet = snippet(current);
    if (thenSnippet === nowSnippet) continue;

    const intensityDelta =
      thenEntry.reflection.emotionalIntensity - current.reflection.emotionalIntensity;
    const hedgeDelta =
      countMatches(thenEntry.transcript, HEDGE_RE) - countMatches(current.transcript, HEDGE_RE);

    let headline = "This sounds different from before.";
    if (intensityDelta >= 1.5) headline = "This sounds lighter than before.";
    else if (hedgeDelta >= 1) headline = "You named this directly this time.";

    const confidence =
      55 +
      Math.round(Math.abs(intensityDelta) * 5) +
      Math.max(0, hedgeDelta) * 4 +
      (thenSnippet.length > 20 && nowSnippet.length > 20 ? 8 : 0);

    if (confidence > bestScore && confidence >= 65) {
      bestScore = confidence;
      best = {
        headline,
        then: {
          entryId: thenEntry.id,
          dateLabel: formatEntryDate(thenEntry.createdAt),
          snippet: thenSnippet,
        },
        now: {
          entryId: current.id,
          dateLabel: formatEntryDate(current.createdAt),
          snippet: nowSnippet,
        },
        confidence,
        subject: theme,
      };
    }
  }

  return best;
}

/** Build continuity callbacks, moments, landmarks, and optional then-vs-now. */
export function buildContinuityMomentsReport(
  entries: JournalEntry[],
  options: ContinuityMomentsOptions = {},
): ContinuityMomentsReport {
  const context = options.context ?? "memory";
  const callbackLimit = options.callbackLimit ?? 3;
  const landmarkLimit = options.landmarkLimit ?? 2;

  const sorted = sortedEntries(entries);
  if (sorted.length < 2) {
    return {
      callbacks: [],
      moments: [],
      landmarks: [],
      hasData: false,
      context,
      generatedAt: new Date().toISOString(),
    };
  }

  let callbacks: ContinuityCallback[] = [];
  if (context === "entry" && options.entryId) {
    callbacks = detectEntryCallbacks(sorted, options.entryId);
  } else {
    callbacks = detectArchiveCallbacks(sorted, context);
  }

  callbacks = pickStrongest(
    filterOrienting(callbacks, (c) => c.text),
    callbackLimit,
  );

  const moments = detectMoments(sorted);
  const landmarkKinds: ContinuityMomentKind[] = [
    "first_calmer_mention",
    "first_direct_mention",
    "last_concern_appearance",
    "recovery_after_spike",
    "phrase_disappearance",
  ];
  const landmarks = pickStrongest(
    moments.filter((m) => landmarkKinds.includes(m.kind)),
    landmarkLimit,
  );

  const thenVsNow =
    context === "entry" && options.entryId
      ? detectThenVsNow(sorted, options.entryId)
      : undefined;

  const hasData =
    callbacks.length > 0 || landmarks.length > 0 || Boolean(thenVsNow);

  return {
    callbacks,
    moments,
    landmarks,
    thenVsNow,
    hasData,
    context,
    generatedAt: new Date().toISOString(),
  };
}

export function getContinuityForEntry(
  entries: JournalEntry[],
  entryId: string,
  limits?: { callbacks?: number; landmarks?: number },
): ContinuityMomentsReport {
  return buildContinuityMomentsReport(entries, {
    context: "entry",
    entryId,
    callbackLimit: limits?.callbacks ?? 3,
    landmarkLimit: limits?.landmarks ?? 2,
  });
}

export function getContinuityForWeekly(
  entries: JournalEntry[],
  limits?: { callbacks?: number; landmarks?: number },
): ContinuityMomentsReport {
  return buildContinuityMomentsReport(entries, {
    context: "weekly",
    callbackLimit: limits?.callbacks ?? 3,
    landmarkLimit: limits?.landmarks ?? 2,
  });
}

export function getContinuityForMonthly(
  entries: JournalEntry[],
  limits?: { callbacks?: number; landmarks?: number },
): ContinuityMomentsReport {
  return buildContinuityMomentsReport(entries, {
    context: "monthly",
    callbackLimit: limits?.callbacks ?? 3,
    landmarkLimit: limits?.landmarks ?? 2,
  });
}

export function getContinuityForMemory(
  entries: JournalEntry[],
  limits?: { callbacks?: number; landmarks?: number },
): ContinuityMomentsReport {
  return buildContinuityMomentsReport(entries, {
    context: "memory",
    callbackLimit: limits?.callbacks ?? 3,
    landmarkLimit: limits?.landmarks ?? 2,
  });
}
