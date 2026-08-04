import { addDaysToKey, daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildEntityMemoryFromEntries } from "@/lib/entity-memory";
import { buildPhraseMemory, type PhraseMemoryRecord } from "@/lib/patterns/phrase-memory";
import { formatEntryDate } from "@/lib/utils";
import type {
  ChangeCandidate,
  ChangeConfidenceLabel,
  ChangeDateRange,
  ChangeDebugReport,
  ChangeDetectionReport,
  ChangeEvidence,
  ChangeKind,
  ChangeScope,
  ChangeSubjectType,
  LongitudinalChange,
} from "@/types/changes";
import type { JournalEntry } from "@/types/journal";

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|i don't know|eventually)\b/gi;
const CERTAINTY_RE = /\b(i know|i will|definitely|clearly|for sure|decided|wrote down|named)\b/gi;
const FUTURE_RE =
  /\b(hope|hopeful|plan|planning|looking forward|next week|tomorrow|ship|shipped)\b/gi;
const VAGUE_FAMILY_RE =
  /\b(family pressure|family stuff|home worries|that thing with family)\b/gi;
const NAMED_FAMILY_RE = /\b(mum|mom|dad|mother|father|sister|brother)\b/gi;

const MIN_ACCEPT = 58;
const ABSENCE_DAYS = 7;

export interface ChangeEngineOptions {
  scope?: ChangeScope;
  limit?: number;
  includeDebug?: boolean;
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function filterScope(entries: JournalEntry[], scope: ChangeScope): JournalEntry[] {
  if (scope === "archive" || scope === "timeline") return entries;
  const days = scope === "weekly" ? 7 : 30;
  const cutoff = addDaysToKey(toDayKey(new Date().toISOString()), -(days - 1));
  return entries.filter((e) => toDayKey(e.createdAt) >= cutoff);
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function confidenceLabel(score: number): ChangeConfidenceLabel {
  if (score >= 72) return "strong";
  if (score >= MIN_ACCEPT) return "moderate";
  return "weak";
}

function evidenceFrom(entry: JournalEntry, snippet?: string): ChangeEvidence {
  return {
    entryId: entry.id,
    dateKey: toDayKey(entry.createdAt),
    dateLabel: formatEntryDate(entry.createdAt),
    snippet:
      snippet ??
      entry.reflection.exactLanguagePattern?.trim() ??
      entry.reflection.concreteObservation?.trim() ??
      entry.transcript.slice(0, 140),
    intensity: entry.reflection.emotionalIntensity,
    mood: entry.reflection.mood,
  };
}

function dateRangeFrom(
  before: ChangeEvidence[],
  after: ChangeEvidence[],
): ChangeDateRange {
  const keys = [...before, ...after].map((e) => e.dateKey).sort();
  const startKey = keys[0] ?? toDayKey(new Date().toISOString());
  const endKey = keys[keys.length - 1] ?? startKey;
  const startLabel = before[0]?.dateLabel.split(",")[0] ?? startKey;
  const endLabel = after[after.length - 1]?.dateLabel.split(",")[0] ?? endKey;
  const label =
    startLabel === endLabel ? startLabel : `${startLabel} → ${endLabel}`;
  return { startKey, endKey, label };
}

function isGenericSummary(text: string): boolean {
  const generic = [
    /emotional state shifted/i,
    /your mood changed/i,
    /patterns in what you said/i,
    /shifted across \d+ reflections/i,
    /this changed over time/i,
  ];
  return generic.some((re) => re.test(text));
}

interface SubjectSeries {
  subject: string;
  subjectType: ChangeSubjectType;
  points: Array<{ entry: JournalEntry; intensity: number }>;
}

function collectThemeSeries(entries: JournalEntry[]): SubjectSeries[] {
  const map = new Map<string, SubjectSeries>();
  for (const entry of entries) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase().trim();
      if (!key) continue;
      const row =
        map.get(key) ??
        ({ subject: theme, subjectType: "theme", points: [] } satisfies SubjectSeries);
      row.points.push({ entry, intensity: entry.reflection.emotionalIntensity });
      map.set(key, row);
    }
  }
  return [...map.values()].filter((s) => s.points.length >= 2);
}

function collectEntitySeries(entries: JournalEntry[]): SubjectSeries[] {
  const snapshot = buildEntityMemoryFromEntries(entries);
  const all = [...snapshot.people, ...snapshot.concerns, ...snapshot.topics];
  const byId = new Map(entries.map((e) => [e.id, e]));
  const results: SubjectSeries[] = [];

  for (const entity of all.filter((e) => e.mentionCount >= 2)) {
    const points = entity.entryIds
      .map((id) => byId.get(id))
      .filter((e): e is JournalEntry => Boolean(e))
      .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime())
      .map((entry) => ({ entry, intensity: entry.reflection.emotionalIntensity }));
    if (points.length >= 2) {
      results.push({
        subject: entity.name,
        subjectType: "entity",
        points,
      });
    }
  }
  return results;
}

function detectTopicIntensityDrop(series: SubjectSeries): ChangeCandidate | null {
  if (series.points.length < 4) return null;

  const mid = Math.floor(series.points.length / 2);
  const before = series.points.slice(0, mid);
  const after = series.points.slice(mid);
  const beforeAvg = roundAvg(before.map((p) => p.intensity));
  const afterAvg = roundAvg(after.map((p) => p.intensity));
  const delta = beforeAvg - afterAvg;

  const scoreBreakdown = {
    entryCount: series.points.length * 4,
    intensityDelta: Math.round(delta * 8),
    recurrence: before.length + after.length,
  };
  const confidence = scoreBreakdown.entryCount + scoreBreakdown.intensityDelta;

  const subjectLower = series.subject.toLowerCase();
  const displaySubject =
    subjectLower.includes("work") ? "work" : series.subject.toLowerCase();

  let summary: string;
  if (subjectLower.includes("work") || subjectLower.includes("deadline")) {
    summary = `${displaySubject.charAt(0).toUpperCase() + displaySubject.slice(1)} still appears often, but the intensity around it dropped from ${beforeAvg}/10 to ${afterAvg}/10.`;
  } else if (subjectLower.includes("money")) {
    summary = `Money entries became calmer — averaging ${beforeAvg}/10 earlier and ${afterAvg}/10 lately.`;
  } else {
    summary = `"${series.subject}" reads less charged now (${beforeAvg}/10 → ${afterAvg}/10).`;
  }

  const beforeEv = before.slice(-2).map((p) => evidenceFrom(p.entry));
  const afterEv = after.slice(0, 2).map((p) => evidenceFrom(p.entry));
  const entryIds = series.points.map((p) => p.entry.id);

  const accepted = confidence >= MIN_ACCEPT && delta >= 1.2;
  const warnings: string[] = [];
  if (delta < 1.2) warnings.push("Intensity drop below 1.2 threshold");
  if (series.points.length < 4) warnings.push("Fewer than 4 mentions");

  return {
    id: `topic-less-charged-${series.subjectType}-${series.subject}`,
    kind: "topic_less_charged",
    summary,
    subject: series.subject,
    subjectType: series.subjectType,
    confidence,
    confidenceLabel: confidenceLabel(confidence),
    dateRange: dateRangeFrom(beforeEv, afterEv),
    beforeEvidence: beforeEv,
    afterEvidence: afterEv,
    entryIds,
    accepted,
    rejectionReason: accepted ? undefined : warnings[0] ?? "Below confidence threshold",
    scoreBreakdown,
    warnings,
  };
}

function detectPhraseStopped(
  phrase: PhraseMemoryRecord,
  sorted: JournalEntry[],
): ChangeCandidate | null {
  if (phrase.count < 3) return null;

  const last = phrase.occurrences[phrase.occurrences.length - 1];
  const daysSince = daysBetweenKeys(last.dateKey, toDayKey(new Date().toISOString()));
  if (daysSince < ABSENCE_DAYS) return null;

  const moneyEntries = sorted.filter((e) =>
    e.reflection.recurringThemes.some((t) => /money/i.test(t)),
  );
  const moneyCalm =
    moneyEntries.length >= 2 &&
    roundAvg(moneyEntries.slice(-3).map((e) => e.reflection.emotionalIntensity)) <=
      roundAvg(moneyEntries.slice(0, 3).map((e) => e.reflection.emotionalIntensity)) - 0.8;

  let summary: string;
  if (phrase.phrase.toLowerCase() === "i should" && moneyCalm) {
    summary = `You stopped saying "${phrase.phrase}" after the money entries became calmer.`;
  } else {
    summary = `You stopped using "${phrase.phrase}" after ${last.dateLabel.split(",")[0] ?? "a while ago"}.`;
  }

  const beforeEv = phrase.occurrences.slice(-2).map((o) => ({
    entryId: o.entryId,
    dateKey: o.dateKey,
    dateLabel: o.dateLabel,
    snippet: o.snippet,
    intensity: o.intensity,
    mood: o.mood,
  }));
  const afterEntry = sorted.find((e) => toDayKey(e.createdAt) > last.dateKey);
  const afterEv = afterEntry ? [evidenceFrom(afterEntry)] : [];

  const scoreBreakdown = {
    phraseCount: phrase.count * 5,
    daysAbsent: Math.min(daysSince, 21),
    crossEntry: phrase.entryIds.length * 3,
  };
  const confidence = scoreBreakdown.phraseCount + scoreBreakdown.daysAbsent + scoreBreakdown.crossEntry;
  const accepted = confidence >= MIN_ACCEPT;

  return {
    id: `phrase-stopped-${phrase.phrase}`,
    kind: "phrase_stopped",
    summary,
    subject: phrase.phrase,
    subjectType: "phrase",
    confidence,
    confidenceLabel: confidenceLabel(confidence),
    dateRange: {
      startKey: phrase.firstSeen,
      endKey: last.dateKey,
      label: `${phrase.firstSeenLabel.split(",")[0]} → last ${last.dateLabel.split(",")[0]}`,
    },
    beforeEvidence: beforeEv,
    afterEvidence: afterEv,
    entryIds: phrase.entryIds,
    accepted,
    rejectionReason: accepted ? undefined : "Below confidence threshold",
    scoreBreakdown,
    warnings: phrase.count < 3 ? ["Phrase used fewer than 3 times"] : [],
  };
}

function detectEntityFrequencyShift(
  entityName: string,
  entries: JournalEntry[],
): ChangeCandidate | null {
  const nameRe = new RegExp(`\\b${entityName}\\b`, "i");
  const mentions = entries.filter((e) => nameRe.test(e.transcript));
  if (mentions.length < 3) return null;

  const mid = Math.floor(mentions.length / 2);
  const earlyMentions = mentions.slice(0, mid);
  const lateMentions = mentions.slice(mid);

  const earlyHedge =
    earlyMentions.reduce((n, e) => n + countMatches(e.transcript, HEDGE_RE), 0) /
    earlyMentions.length;
  const lateHedge =
    lateMentions.reduce((n, e) => n + countMatches(e.transcript, HEDGE_RE), 0) /
    lateMentions.length;
  const lateCert = lateMentions.reduce((n, e) => n + countMatches(e.transcript, CERTAINTY_RE), 0);

  if (lateHedge >= earlyHedge - 0.2 && lateCert < 1) return null;

  const earlyCount = earlyMentions.length;
  const lateCount = lateMentions.length;
  const frequencyDropped = lateCount < earlyCount;

  let summary: string;
  if (frequencyDropped && lateHedge < earlyHedge) {
    summary = `You mention ${entityName} less now, but when ${entityName === "Sarah" ? "she" : "they"} appears the language is more direct.`;
  } else if (lateHedge < earlyHedge - 0.3) {
    summary = `When ${entityName} comes up lately, your language is more direct.`;
  } else {
    return null;
  }

  const beforeEv = earlyMentions.slice(-1).map((e) => evidenceFrom(e));
  const afterEv = lateMentions.slice(0, 1).map((e) => evidenceFrom(e));
  const scoreBreakdown = {
    mentions: mentions.length * 4,
    hedgeDrop: Math.round((earlyHedge - lateHedge) * 10),
    directness: lateCert * 5,
  };
  const confidence = scoreBreakdown.mentions + scoreBreakdown.hedgeDrop + scoreBreakdown.directness;
  const accepted = confidence >= MIN_ACCEPT;

  return {
    id: `entity-shift-${entityName}`,
    kind: "more_direct",
    summary,
    subject: entityName,
    subjectType: "entity",
    confidence,
    confidenceLabel: confidenceLabel(confidence),
    dateRange: dateRangeFrom(beforeEv, afterEv),
    beforeEvidence: beforeEv,
    afterEvidence: afterEv,
    entryIds: mentions.map((e) => e.id),
    accepted,
    rejectionReason: accepted ? undefined : "Insufficient directness shift",
    scoreBreakdown,
    warnings: [],
  };
}

function detectFamilyDirectness(sorted: JournalEntry[]): ChangeCandidate | null {
  const familyEntries = sorted.filter(
    (e) =>
      e.reflection.recurringThemes.some((t) => /family/i.test(t)) ||
      VAGUE_FAMILY_RE.test(e.transcript) ||
      NAMED_FAMILY_RE.test(e.transcript),
  );
  if (familyEntries.length < 4) return null;

  const mid = Math.floor(familyEntries.length / 2);
  const early = familyEntries.slice(0, mid);
  const late = familyEntries.slice(mid);

  const vagueEarly = early.filter((e) => VAGUE_FAMILY_RE.test(e.transcript)).length;
  const namedLate = late.filter((e) => NAMED_FAMILY_RE.test(e.transcript)).length;
  const hedgeEarly =
    early.reduce((n, e) => n + countMatches(e.transcript, HEDGE_RE), 0) / early.length;
  const hedgeLate =
    late.reduce((n, e) => n + countMatches(e.transcript, HEDGE_RE), 0) / late.length;

  if (namedLate < 1 || (vagueEarly < 1 && hedgeLate >= hedgeEarly - 0.3)) return null;

  const summary =
    vagueEarly >= 1 && namedLate >= 1
      ? "Family pressure moved from vague references to named conversations."
      : "You became more direct when discussing family.";

  const beforeEv = early.filter((e) => VAGUE_FAMILY_RE.test(e.transcript) || countMatches(e.transcript, HEDGE_RE) > 0).slice(-2).map((e) => evidenceFrom(e));
  const afterEv = late.filter((e) => NAMED_FAMILY_RE.test(e.transcript)).slice(0, 2).map((e) => evidenceFrom(e));
  if (beforeEv.length === 0) beforeEv.push(...early.slice(-1).map((e) => evidenceFrom(e)));
  if (afterEv.length === 0) afterEv.push(...late.slice(0, 1).map((e) => evidenceFrom(e)));

  const scoreBreakdown = {
    familyEntries: familyEntries.length * 3,
    namedShift: namedLate * 8,
    hedgeDrop: Math.round((hedgeEarly - hedgeLate) * 8),
  };
  const confidence = scoreBreakdown.familyEntries + scoreBreakdown.namedShift + scoreBreakdown.hedgeDrop;
  const accepted = confidence >= MIN_ACCEPT;

  return {
    id: "family-more-direct",
    kind: "more_direct",
    summary,
    subject: "family",
    subjectType: "topic",
    confidence,
    confidenceLabel: confidenceLabel(confidence),
    dateRange: dateRangeFrom(beforeEv, afterEv),
    beforeEvidence: beforeEv,
    afterEvidence: afterEv,
    entryIds: familyEntries.map((e) => e.id),
    accepted,
    rejectionReason: accepted ? undefined : "Family directness shift too weak",
    scoreBreakdown,
    warnings: namedLate < 1 ? ["No named family references in later entries"] : [],
  };
}

function detectGlobalCalm(sorted: JournalEntry[]): ChangeCandidate | null {
  if (sorted.length < 5) return null;

  const recent = sorted.slice(-Math.min(8, sorted.length));
  const prior = sorted.slice(
    Math.max(0, sorted.length - 16),
    Math.max(0, sorted.length - 8),
  );
  if (prior.length < 3) return null;

  const recentAvg = roundAvg(recent.map((e) => e.reflection.emotionalIntensity));
  const priorAvg = roundAvg(prior.map((e) => e.reflection.emotionalIntensity));
  const delta = priorAvg - recentAvg;
  if (delta < 1) return null;

  const beforeEv = prior.slice(-2).map((e) => evidenceFrom(e));
  const afterEv = recent.slice(0, 2).map((e) => evidenceFrom(e));

  const scoreBreakdown = {
    intensityDrop: Math.round(delta * 10),
    entrySpan: recent.length + prior.length,
  };
  const confidence = scoreBreakdown.intensityDrop + scoreBreakdown.entrySpan;
  const accepted = confidence >= MIN_ACCEPT;

  return {
    id: "global-calm",
    kind: "became_calm",
    summary: `Your entries read calmer lately (${priorAvg}/10 → ${recentAvg}/10).`,
    subject: "intensity",
    subjectType: "language",
    confidence,
    confidenceLabel: confidenceLabel(confidence),
    dateRange: dateRangeFrom(beforeEv, afterEv),
    beforeEvidence: beforeEv,
    afterEvidence: afterEv,
    entryIds: [...prior, ...recent].map((e) => e.id),
    accepted,
    rejectionReason: accepted ? undefined : "Intensity drop too small",
    scoreBreakdown,
    warnings: delta < 1.5 ? ["Modest intensity drop"] : [],
  };
}

function detectLessHedging(sorted: JournalEntry[]): ChangeCandidate | null {
  if (sorted.length < 5) return null;

  const mid = Math.floor(sorted.length / 2);
  const early = sorted.slice(0, mid);
  const late = sorted.slice(mid);
  const hedgeEarly =
    early.reduce((n, e) => n + countMatches(e.transcript, HEDGE_RE), 0) / early.length;
  const hedgeLate =
    late.reduce((n, e) => n + countMatches(e.transcript, HEDGE_RE), 0) / late.length;

  if (hedgeLate >= hedgeEarly - 0.35 || hedgeEarly < 0.8) return null;

  const beforeEv = early.filter((e) => countMatches(e.transcript, HEDGE_RE) > 0).slice(-2).map((e) => evidenceFrom(e));
  const afterEv = late.filter((e) => countMatches(e.transcript, HEDGE_RE) === 0).slice(0, 2).map((e) => evidenceFrom(e));
  if (beforeEv.length === 0) beforeEv.push(...early.slice(-1).map((e) => evidenceFrom(e)));
  if (afterEv.length === 0) afterEv.push(...late.slice(-1).map((e) => evidenceFrom(e)));

  const scoreBreakdown = {
    hedgeDrop: Math.round((hedgeEarly - hedgeLate) * 12),
    entries: sorted.length,
  };
  const confidence = scoreBreakdown.hedgeDrop + scoreBreakdown.entries;
  const accepted = confidence >= MIN_ACCEPT;

  return {
    id: "less-hedged",
    kind: "less_hedged",
    summary: "Your language became less hedged — fewer \"maybe\" and \"I guess\" lately.",
    subject: "hedging",
    subjectType: "language",
    confidence,
    confidenceLabel: confidenceLabel(confidence),
    dateRange: dateRangeFrom(beforeEv, afterEv),
    beforeEvidence: beforeEv,
    afterEvidence: afterEv,
    entryIds: sorted.map((e) => e.id),
    accepted,
    rejectionReason: accepted ? undefined : "Hedge reduction too weak",
    scoreBreakdown,
    warnings: [],
  };
}

function detectFutureOriented(sorted: JournalEntry[]): ChangeCandidate | null {
  if (sorted.length < 4) return null;

  const mid = Math.floor(sorted.length / 2);
  const futureEarly = sorted.slice(0, mid).reduce((n, e) => n + countMatches(e.transcript, FUTURE_RE), 0);
  const futureLate = sorted.slice(mid).reduce((n, e) => n + countMatches(e.transcript, FUTURE_RE), 0);

  if (futureLate <= futureEarly + 1) return null;

  const lateEntries = sorted.slice(mid).filter((e) => FUTURE_RE.test(e.transcript));
  const beforeEv = sorted.slice(0, mid).slice(-1).map((e) => evidenceFrom(e));
  const afterEv = lateEntries.slice(0, 2).map((e) => evidenceFrom(e));

  const scoreBreakdown = {
    futureDelta: (futureLate - futureEarly) * 6,
    lateHits: lateEntries.length * 4,
  };
  const confidence = scoreBreakdown.futureDelta + scoreBreakdown.lateHits;
  const accepted = confidence >= MIN_ACCEPT;

  return {
    id: "more-future",
    kind: "more_future_oriented",
    summary: "More forward-looking language in recent entries — plans and next steps show up more often.",
    subject: "future language",
    subjectType: "language",
    confidence,
    confidenceLabel: confidenceLabel(confidence),
    dateRange: dateRangeFrom(beforeEv, afterEv),
    beforeEvidence: beforeEv,
    afterEvidence: afterEv,
    entryIds: lateEntries.map((e) => e.id),
    accepted,
    rejectionReason: accepted ? undefined : "Future language increase too weak",
    scoreBreakdown,
    warnings: [],
  };
}

function detectPatternLifecycle(
  series: SubjectSeries,
  sorted: JournalEntry[],
): ChangeCandidate[] {
  const results: ChangeCandidate[] = [];
  const points = series.points;
  const entryIds = points.map((p) => p.entry.id);
  const first = points[0];
  const last = points[points.length - 1];

  if (points.length === 2) {
    const delta = points[1].intensity - points[0].intensity;
    if (delta >= 2) {
      const summary = `"${series.subject}" showed up with more charge after ${formatEntryDate(first.entry.createdAt).split(",")[0]}.`;
      const beforeEv = [evidenceFrom(first.entry)];
      const afterEv = [evidenceFrom(points[1].entry)];
      const confidence = 52 + delta * 5;
      results.push({
        id: `started-intense-${series.subject}`,
        kind: "pattern_intensified",
        summary,
        subject: series.subject,
        subjectType: series.subjectType,
        confidence,
        confidenceLabel: confidenceLabel(confidence),
        dateRange: dateRangeFrom(beforeEv, afterEv),
        beforeEvidence: beforeEv,
        afterEvidence: afterEv,
        entryIds,
        accepted: confidence >= MIN_ACCEPT,
        rejectionReason: confidence >= MIN_ACCEPT ? undefined : "Below confidence threshold",
        scoreBreakdown: { intensityJump: delta * 5 },
        warnings: [],
      });
    }
  }

  const daysSinceLast = daysBetweenKeys(
    toDayKey(last.entry.createdAt),
    toDayKey(new Date().toISOString()),
  );
  if (points.length >= 3 && daysSinceLast >= ABSENCE_DAYS) {
    const beforeEv = points.slice(-2).map((p) => evidenceFrom(p.entry));
    const afterEntry = sorted.find((e) => toDayKey(e.createdAt) > toDayKey(last.entry.createdAt));
    const afterEv = afterEntry ? [evidenceFrom(afterEntry)] : [];
    const confidence = 54 + points.length * 4 + Math.min(daysSinceLast, 14);
    const summary = `"${series.subject}" faded from your saved words after ${last.entry.createdAt ? formatEntryDate(last.entry.createdAt).split(",")[0] : "a while ago"}.`;

    results.push({
      id: `faded-${series.subjectType}-${series.subject}`,
      kind: "pattern_faded",
      summary,
      subject: series.subject,
      subjectType: series.subjectType,
      confidence,
      confidenceLabel: confidenceLabel(confidence),
      dateRange: dateRangeFrom(beforeEv, afterEv),
      beforeEvidence: beforeEv,
      afterEvidence: afterEv,
      entryIds,
      accepted: confidence >= MIN_ACCEPT,
      rejectionReason: confidence >= MIN_ACCEPT ? undefined : "Below confidence threshold",
      scoreBreakdown: { absence: daysSinceLast, mentions: points.length * 3 },
      warnings: [],
    });
  }

  for (let i = 1; i < points.length; i += 1) {
    const gap = daysBetweenKeys(
      toDayKey(points[i - 1].entry.createdAt),
      toDayKey(points[i].entry.createdAt),
    );
    if (gap >= ABSENCE_DAYS + 3) {
      const beforeEv = [evidenceFrom(points[i - 1].entry)];
      const afterEv = [evidenceFrom(points[i].entry)];
      const confidence = 56 + gap;
      const summary = `"${series.subject}" came back after ${gap} days away.`;

      results.push({
        id: `returned-${series.subjectType}-${series.subject}-${i}`,
        kind: "pattern_returned",
        summary,
        subject: series.subject,
        subjectType: series.subjectType,
        confidence,
        confidenceLabel: confidenceLabel(confidence),
        dateRange: dateRangeFrom(beforeEv, afterEv),
        beforeEvidence: beforeEv,
        afterEvidence: afterEv,
        entryIds: [points[i - 1].entry.id, points[i].entry.id],
        accepted: confidence >= MIN_ACCEPT,
        rejectionReason: confidence >= MIN_ACCEPT ? undefined : "Below confidence threshold",
        scoreBreakdown: { gapDays: gap },
        warnings: [],
      });
    }
  }

  if (points.length >= 2 && points.length <= 3) {
    const firstThird = points.slice(0, 1);
    const confidence = 50 + points.length * 5;
    const summary = `"${series.subject}" started showing up in your saved words around ${formatEntryDate(first.entry.createdAt).split(",")[0]}.`;
    results.push({
      id: `started-${series.subjectType}-${series.subject}`,
      kind: "pattern_started",
      summary,
      subject: series.subject,
      subjectType: series.subjectType,
      confidence,
      confidenceLabel: confidenceLabel(confidence),
      dateRange: dateRangeFrom(
        firstThird.map((p) => evidenceFrom(p.entry)),
        points.slice(1, 2).map((p) => evidenceFrom(p.entry)),
      ),
      beforeEvidence: [],
      afterEvidence: points.slice(0, 2).map((p) => evidenceFrom(p.entry)),
      entryIds,
      accepted: confidence >= MIN_ACCEPT,
      rejectionReason: confidence >= MIN_ACCEPT ? undefined : "Below confidence threshold",
      scoreBreakdown: { newPattern: points.length * 5 },
      warnings: points.length < 2 ? ["Only one mention"] : [],
    });
  }

  return results;
}

function collectCandidates(sorted: JournalEntry[]): ChangeCandidate[] {
  const candidates: ChangeCandidate[] = [];
  const phrases = buildPhraseMemory(sorted);
  const themeSeries = collectThemeSeries(sorted);
  const entitySeries = collectEntitySeries(sorted);

  for (const phrase of phrases) {
    const c = detectPhraseStopped(phrase, sorted);
    if (c) candidates.push(c);
  }

  for (const series of [...themeSeries, ...entitySeries]) {
    const intensity = detectTopicIntensityDrop(series);
    if (intensity) candidates.push(intensity);
    candidates.push(...detectPatternLifecycle(series, sorted));
  }

  const sarah = detectEntityFrequencyShift("Sarah", sorted);
  if (sarah) candidates.push(sarah);

  const family = detectFamilyDirectness(sorted);
  if (family) candidates.push(family);

  const calm = detectGlobalCalm(sorted);
  if (calm) candidates.push(calm);

  const hedge = detectLessHedging(sorted);
  if (hedge) candidates.push(hedge);

  const future = detectFutureOriented(sorted);
  if (future) candidates.push(future);

  return candidates.filter((c) => !isGenericSummary(c.summary));
}

function dedupeCandidates(candidates: ChangeCandidate[]): ChangeCandidate[] {
  const seen = new Set<string>();
  const result: ChangeCandidate[] = [];

  for (const c of candidates.sort((a, b) => b.confidence - a.confidence)) {
    const key = `${c.kind}:${c.subject.toLowerCase().slice(0, 24)}`;
    if (seen.has(key)) continue;
    const overlap = result.some(
      (r) =>
        r.subject.toLowerCase() === c.subject.toLowerCase() &&
        r.kind === c.kind,
    );
    if (overlap) continue;
    seen.add(key);
    result.push(c);
  }

  return result;
}

function toChange(candidate: ChangeCandidate): LongitudinalChange {
  const { accepted: _a, rejectionReason: _r, scoreBreakdown: _s, warnings: _w, ...change } =
    candidate;
  return change;
}

/** Build top longitudinal changes — evidence-gated, human copy. */
export function buildChangeReport(
  entries: JournalEntry[],
  options: ChangeEngineOptions = {},
): ChangeDetectionReport {
  const scope = options.scope ?? "archive";
  const limit = options.limit ?? 3;

  const scoped = filterScope(entries, scope);
  const sorted = sortedEntries(scoped);

  if (sorted.length < 2) {
    return {
      changes: [],
      hasData: false,
      scope,
      generatedAt: new Date().toISOString(),
    };
  }

  const candidates = dedupeCandidates(collectCandidates(sorted));
  const accepted = candidates
    .filter((c) => c.accepted)
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, limit)
    .map(toChange);

  return {
    changes: accepted,
    hasData: accepted.length > 0,
    scope,
    generatedAt: new Date().toISOString(),
  };
}

/** Debug view — all candidates with accept/reject reasoning. */
export function buildChangeDebugReport(
  entries: JournalEntry[],
  options: ChangeEngineOptions = {},
): ChangeDebugReport {
  const scope = options.scope ?? "archive";
  const scoped = filterScope(entries, scope);
  const sorted = sortedEntries(scoped);
  const candidates = dedupeCandidates(collectCandidates(sorted));

  const accepted = candidates.filter((c) => c.accepted);
  const rejected = candidates.filter((c) => !c.accepted);
  const averageConfidence =
    candidates.length > 0
      ? Math.round(
          candidates.reduce((n, c) => n + c.confidence, 0) / candidates.length,
        )
      : 0;

  return {
    candidates,
    accepted,
    rejected,
    averageConfidence,
    generatedAt: new Date().toISOString(),
  };
}

export function getChangesForWeekly(entries: JournalEntry[], limit = 3): ChangeDetectionReport {
  return buildChangeReport(entries, { scope: "weekly", limit });
}

export function getChangesForMonthly(entries: JournalEntry[], limit = 3): ChangeDetectionReport {
  return buildChangeReport(entries, { scope: "monthly", limit });
}

export function getChangesForTimeline(entries: JournalEntry[], limit = 3): ChangeDetectionReport {
  return buildChangeReport(entries, { scope: "timeline", limit });
}

export { MIN_ACCEPT as CHANGE_MIN_CONFIDENCE };
