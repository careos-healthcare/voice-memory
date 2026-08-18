import { addDaysToKey, daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildEntityMemoryFromEntries } from "@/lib/entity-memory";
import { buildPhraseMemory, type PhraseMemoryRecord } from "@/lib/patterns/phrase-memory";
import { formatEntryDate } from "@/lib/utils";
import type {
  ContinuityEvidence,
  ContinuityItem,
  ContinuityReport,
  ContinuityScope,
  ContinuitySurfaceLabel,
  IdentityDriftInsight,
  NarrativeArc,
  PeriodSummary,
  TimelinePhase,
} from "@/types/continuity";
import type { JournalEntry } from "@/types/journal";

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|i don't know|eventually)\b/gi;
const CERTAINTY_RE = /\b(i know|i will|definitely|clearly|for sure|decided)\b/gi;
const FUTURE_RE = /\b(hope|hopeful|plan|planning|looking forward|excited|next week|tomorrow)\b/gi;
const FLAT_RE = /\b(stuck|pointless|what's the point|no point|never|always fail)\b/gi;
const ABSENCE_GAP_DAYS = 7;
const MIN_CONFIDENCE = 45;

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function monthLabel(dayKey: string): string {
  const [y, m] = dayKey.split("-").map(Number);
  return new Intl.DateTimeFormat("en-US", { month: "long", year: "numeric" }).format(
    new Date(y, m - 1, 1),
  );
}

function quarterLabel(dayKey: string): string {
  const [y, m] = dayKey.split("-").map(Number);
  const q = Math.ceil(m / 3);
  return `Q${q} ${y}`;
}

function monthKey(iso: string): string {
  const key = toDayKey(iso);
  return key.slice(0, 7);
}

function quarterKey(iso: string): string {
  const [y, m] = toDayKey(iso).split("-").map(Number);
  return `${y}-Q${Math.ceil(m / 3)}`;
}

function evidenceFrom(entry: JournalEntry): ContinuityEvidence {
  const phrase =
    entry.reflection.exactLanguagePattern?.trim() ||
    entry.reflection.concreteObservation?.trim() ||
    entry.transcript.slice(0, 120);
  return {
    entryId: entry.id,
    dateKey: toDayKey(entry.createdAt),
    dateLabel: formatEntryDate(entry.createdAt),
    phrase,
    mood: entry.reflection.mood,
    intensity: entry.reflection.emotionalIntensity,
  };
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function surfaceHeadline(surface: ContinuitySurfaceLabel): string {
  switch (surface) {
    case "changed_over_time":
      return "This changed over time";
    case "disappeared":
      return "This disappeared";
    case "more_intense":
      return "This became more intense";
    case "calmer":
      return "This became calmer";
    case "reappeared":
      return "This came back";
    case "emerged":
      return "This emerged";
  }
}

function pushItem(
  bucket: ContinuityItem[],
  item: Omit<ContinuityItem, "confidence"> & { confidence?: number },
): void {
  const confidence = item.confidence ?? 50;
  if (confidence < MIN_CONFIDENCE) return;
  bucket.push({ ...item, confidence });
}

interface SubjectSeries {
  subject: string;
  subjectType: ContinuityItem["subjectType"];
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
  const all = [
    ...snapshot.people,
    ...snapshot.concerns,
    ...snapshot.goals,
    ...snapshot.topics,
  ];
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

function collectPhraseSeries(
  phrases: PhraseMemoryRecord[],
  entries: JournalEntry[],
): SubjectSeries[] {
  const byId = new Map(entries.map((e) => [e.id, e]));

  return phrases
    .filter((p) => p.entryIds.length >= 2)
    .map((p) => ({
      subject: p.phrase,
      subjectType: "phrase" as const,
      points: p.occurrences
        .map((o) => {
          const entry = byId.get(o.entryId);
          if (!entry) return null;
          return { entry, intensity: o.intensity };
        })
        .filter((pt): pt is { entry: JournalEntry; intensity: number } => pt !== null)
        .sort(
          (a, b) =>
            new Date(a.entry.createdAt).getTime() - new Date(b.entry.createdAt).getTime(),
        ),
    }))
    .filter((s) => s.points.length >= 2);
}

function detectPhases(series: SubjectSeries): TimelinePhase[] {
  const phases: TimelinePhase[] = [];
  const points = series.points;
  const first = points[0];
  const last = points[points.length - 1];

  phases.push({
    kind: "first_appearance",
    startKey: toDayKey(first.entry.createdAt),
    endKey: toDayKey(first.entry.createdAt),
    startLabel: formatEntryDate(first.entry.createdAt),
    endLabel: formatEntryDate(first.entry.createdAt),
    avgIntensity: first.intensity,
    note: `First tagged at ${first.intensity}/10 intensity.`,
  });

  let peak = points[0];
  for (const p of points) {
    if (p.intensity > peak.intensity) peak = p;
  }
  if (peak.entry.id !== first.entry.id) {
    phases.push({
      kind: "peak",
      startKey: toDayKey(peak.entry.createdAt),
      endKey: toDayKey(peak.entry.createdAt),
      startLabel: formatEntryDate(peak.entry.createdAt),
      endLabel: formatEntryDate(peak.entry.createdAt),
      avgIntensity: peak.intensity,
      note: `Peaked at ${peak.intensity}/10.`,
    });
  }

  if (points.length >= 3) {
    const firstThird = points.slice(0, Math.ceil(points.length / 3));
    const lastThird = points.slice(-Math.ceil(points.length / 3));
    const early = roundAvg(firstThird.map((p) => p.intensity));
    const late = roundAvg(lastThird.map((p) => p.intensity));
    if (late <= early - 1.2) {
      phases.push({
        kind: "decline",
        startKey: toDayKey(firstThird[0].entry.createdAt),
        endKey: toDayKey(lastThird[lastThird.length - 1].entry.createdAt),
        startLabel: formatEntryDate(firstThird[0].entry.createdAt),
        endLabel: formatEntryDate(lastThird[lastThird.length - 1].entry.createdAt),
        avgIntensity: late,
        note: `Intensity eased from ~${early}/10 to ~${late}/10.`,
      });
    }
  }

  for (let i = 1; i < points.length; i += 1) {
    const gap = daysBetweenKeys(
      toDayKey(points[i - 1].entry.createdAt),
      toDayKey(points[i].entry.createdAt),
    );
    if (gap >= ABSENCE_GAP_DAYS) {
      phases.push({
        kind: "absence",
        startKey: toDayKey(points[i - 1].entry.createdAt),
        endKey: toDayKey(points[i].entry.createdAt),
        startLabel: formatEntryDate(points[i - 1].entry.createdAt),
        endLabel: formatEntryDate(points[i].entry.createdAt),
        note: `No mention for ${gap} days.`,
      });
      phases.push({
        kind: "reappearance",
        startKey: toDayKey(points[i].entry.createdAt),
        endKey: toDayKey(points[i].entry.createdAt),
        startLabel: formatEntryDate(points[i].entry.createdAt),
        endLabel: formatEntryDate(points[i].entry.createdAt),
        avgIntensity: points[i].intensity,
        note: `Returned after ${gap} days at ${points[i].intensity}/10.`,
      });
    }
  }

  if (last.entry.id !== first.entry.id && last.intensity < peak.intensity - 1) {
    const lastKey = toDayKey(last.entry.createdAt);
    if (!phases.some((p) => p.kind === "decline" && p.endKey === lastKey)) {
      phases.push({
        kind: "decline",
        startKey: toDayKey(peak.entry.createdAt),
        endKey: lastKey,
        startLabel: formatEntryDate(peak.entry.createdAt),
        endLabel: formatEntryDate(last.entry.createdAt),
        avgIntensity: last.intensity,
        note: `Latest mention reads calmer (${last.intensity}/10 vs peak ${peak.intensity}/10).`,
      });
    }
  }

  return phases;
}

function timelineItemsFromSeries(
  series: SubjectSeries[],
  bucket: ContinuityItem[],
): void {
  for (const s of series) {
    const phases = detectPhases(s);
    const entryIds = s.points.map((p) => p.entry.id);
    const evidence = s.points.slice(-4).map((p) => evidenceFrom(p.entry));

    const decline = phases.find((p) => p.kind === "decline");
    const peak = phases.find((p) => p.kind === "peak");
    const absence = phases.find((p) => p.kind === "absence");
    const reappearance = phases.find((p) => p.kind === "reappearance");

    if (decline) {
      pushItem(bucket, {
        id: `timeline-decline-${s.subjectType}-${s.subject}`,
        kind: "timeline_phase",
        surface: "calmer",
        title: `${capitalize(s.subject)} became calmer over time.`,
        detail: decline.note,
        subject: s.subject,
        subjectType: s.subjectType,
        entryIds,
        evidence,
        phases,
        confidence: 55 + entryIds.length * 4,
      });
    }

    if (peak && !decline) {
      pushItem(bucket, {
        id: `timeline-peak-${s.subjectType}-${s.subject}`,
        kind: "timeline_phase",
        surface: "more_intense",
        title: `${capitalize(s.subject)} hit a peak around ${peak.startLabel}.`,
        detail: peak.note,
        subject: s.subject,
        subjectType: s.subjectType,
        entryIds,
        evidence,
        phases,
        confidence: 50 + entryIds.length * 3,
      });
    }

    if (absence && reappearance) {
      pushItem(bucket, {
        id: `timeline-reappear-${s.subjectType}-${s.subject}`,
        kind: "timeline_phase",
        surface: "reappeared",
        title: `"${s.subject}" dropped out, then came back.`,
        detail: `${absence.note} ${reappearance.note}`,
        subject: s.subject,
        subjectType: s.subjectType,
        entryIds,
        evidence,
        phases,
        confidence: 58,
      });
    } else if (absence && s.points.length >= 3) {
      const lastMention = s.points[s.points.length - 1];
      const daysSince = daysBetweenKeys(
        toDayKey(lastMention.entry.createdAt),
        toDayKey(new Date().toISOString()),
      );
      if (daysSince >= ABSENCE_GAP_DAYS) {
        pushItem(bucket, {
          id: `timeline-gone-${s.subjectType}-${s.subject}`,
          kind: "timeline_phase",
          surface: "disappeared",
          title: `"${s.subject}" faded from your reflections.`,
          detail: `Last mentioned ${lastMention.intensity}/10 on ${formatEntryDate(lastMention.entry.createdAt)} — absent for ${daysSince}+ days since.`,
          subject: s.subject,
          subjectType: s.subjectType,
          entryIds,
          evidence: [evidenceFrom(lastMention.entry)],
          phases,
          confidence: 52,
        });
      }
    }

    if (phases.length >= 2 && !decline && !peak && !absence) {
      pushItem(bucket, {
        id: `timeline-change-${s.subjectType}-${s.subject}`,
        kind: "timeline_phase",
        surface: "changed_over_time",
        title: `"${s.subject}" shifted across ${entryIds.length} reflections.`,
        detail: phases.map((p) => p.note).join(" "),
        subject: s.subject,
        subjectType: s.subjectType,
        entryIds,
        evidence,
        phases,
        confidence: 48 + entryIds.length * 3,
      });
    }
  }
}

function detectChangeMoments(sorted: JournalEntry[]): ContinuityItem[] {
  const items: ContinuityItem[] = [];
  const seenMoods = new Set<string>();

  for (let i = 1; i < sorted.length; i += 1) {
    const prev = sorted[i - 1];
    const curr = sorted[i];
    const delta = curr.reflection.emotionalIntensity - prev.reflection.emotionalIntensity;

    if (Math.abs(delta) >= 3) {
      pushItem(items, {
        id: `shift-${prev.id}-${curr.id}`,
        kind: "change_moment",
        surface: delta > 0 ? "more_intense" : "calmer",
        title:
          delta > 0
            ? `Intensity jumped ${prev.reflection.emotionalIntensity} → ${curr.reflection.emotionalIntensity}/10 between consecutive entries.`
            : `Intensity dropped ${prev.reflection.emotionalIntensity} → ${curr.reflection.emotionalIntensity}/10 between consecutive entries.`,
        detail: `${formatEntryDate(prev.createdAt)} (${prev.reflection.mood}) → ${formatEntryDate(curr.createdAt)} (${curr.reflection.mood}).`,
        subject: "intensity",
        subjectType: "emotion",
        entryIds: [prev.id, curr.id],
        evidence: [evidenceFrom(prev), evidenceFrom(curr)],
        confidence: 60 + Math.abs(delta) * 3,
      });
    }

    const mood = curr.reflection.mood.toLowerCase();
    if (!seenMoods.has(mood)) {
      seenMoods.add(mood);
      if (i >= 2) {
        pushItem(items, {
          id: `mood-emerged-${mood}-${curr.id}`,
          kind: "change_moment",
          surface: "emerged",
          title: `"${curr.reflection.mood}" showed up as a new mood label.`,
          detail: `First tagged on ${formatEntryDate(curr.createdAt)} at ${curr.reflection.emotionalIntensity}/10.`,
          subject: curr.reflection.mood,
          subjectType: "emotion",
          entryIds: [curr.id],
          evidence: [evidenceFrom(curr)],
          confidence: 50,
        });
      }
    }
  }

  if (sorted.length >= 6) {
    const recent = sorted.slice(-6);
    const hedgeEarly = recent
      .slice(0, 3)
      .reduce((n, e) => n + (e.transcript.match(HEDGE_RE)?.length ?? 0), 0);
    const hedgeLate = recent
      .slice(3)
      .reduce((n, e) => n + (e.transcript.match(HEDGE_RE)?.length ?? 0), 0);
    const intEarly = roundAvg(recent.slice(0, 3).map((e) => e.reflection.emotionalIntensity));
    const intLate = roundAvg(recent.slice(3).map((e) => e.reflection.emotionalIntensity));

    if (hedgeLate < hedgeEarly - 1 && hedgeEarly >= 2) {
      pushItem(items, {
        id: "language-more-direct",
        kind: "change_moment",
        surface: "calmer",
        title: "Your recent language reads more direct — fewer hedges.",
        detail: `Hedging phrases dropped in the last three entries vs the three before.`,
        subject: "hedging",
        subjectType: "identity",
        entryIds: recent.map((e) => e.id),
        evidence: recent.slice(-3).map(evidenceFrom),
        confidence: 55,
      });
    }

    if (intLate <= intEarly - 1.5) {
      pushItem(items, {
        id: "language-calmer-recent",
        kind: "change_moment",
        surface: "calmer",
        title: "Your last few entries sound less charged.",
        detail: `Recent average ${intLate}/10 vs ${intEarly}/10 in the prior three.`,
        subject: "intensity",
        subjectType: "emotion",
        entryIds: recent.map((e) => e.id),
        evidence: recent.slice(-3).map(evidenceFrom),
        confidence: 54,
      });
    }
  }

  return items;
}

function detectBeforeAfter(
  sorted: JournalEntry[],
  phrases: PhraseMemoryRecord[],
  themeSeries: SubjectSeries[],
): ContinuityItem[] {
  const items: ContinuityItem[] = [];

  for (const phrase of phrases.filter((p) => p.count >= 3)) {
    const lastOcc = phrase.occurrences[phrase.occurrences.length - 1];
    const daysSince = daysBetweenKeys(lastOcc.dateKey, toDayKey(new Date().toISOString()));
    if (daysSince < ABSENCE_GAP_DAYS) continue;

    pushItem(items, {
      id: `before-after-phrase-${phrase.phrase}`,
      kind: "before_after",
      surface: "disappeared",
      title: `You stopped using "${phrase.phrase}" after ${lastOcc.dateLabel.split(",")[0] ?? lastOcc.dateLabel}.`,
      detail: `${phrase.count} uses across ${phrase.entryIds.length} entries — last on ${lastOcc.dateLabel}.`,
      subject: phrase.phrase,
      subjectType: "phrase",
      entryIds: phrase.entryIds,
      evidence: phrase.occurrences.slice(-2).map((o) => ({
        entryId: o.entryId,
        dateKey: o.dateKey,
        dateLabel: o.dateLabel,
        phrase: o.snippet,
        mood: o.mood,
        intensity: o.intensity,
      })),
      confidence: 56 + phrase.count * 2,
    });
  }

  for (const series of themeSeries) {
    if (series.points.length < 4) continue;
    const mid = Math.floor(series.points.length / 2);
    const before = series.points.slice(0, mid);
    const after = series.points.slice(mid);
    const beforeAvg = roundAvg(before.map((p) => p.intensity));
    const afterAvg = roundAvg(after.map((p) => p.intensity));
    if (afterAvg <= beforeAvg - 1.2) {
      const pivot = before[before.length - 1];
      pushItem(items, {
        id: `before-after-theme-${series.subject}`,
        kind: "before_after",
        surface: "calmer",
        title: `"${series.subject}" entries became less intense after ${formatEntryDate(pivot.entry.createdAt).split(",")[0]}.`,
        detail: `Before: ~${beforeAvg}/10 · After: ~${afterAvg}/10 across your archive.`,
        subject: series.subject,
        subjectType: "theme",
        entryIds: series.points.map((p) => p.entry.id),
        evidence: [evidenceFrom(pivot.entry), evidenceFrom(after[0].entry)],
        confidence: 58,
      });
    }
  }

  for (const entry of sorted) {
    const text = entry.transcript.toLowerCase();
    if (!text.includes("sarah")) continue;

    const workAfter = sorted.filter(
      (e) =>
        new Date(e.createdAt) > new Date(entry.createdAt) &&
        e.reflection.recurringThemes.some((t) => /work|deadline|project/i.test(t)),
    );
    if (workAfter.length < 2) continue;

    const workBefore = sorted.filter(
      (e) =>
        new Date(e.createdAt) < new Date(entry.createdAt) &&
        e.reflection.recurringThemes.some((t) => /work|deadline|project/i.test(t)),
    );
    if (workBefore.length < 2) continue;

    const beforeAvg = roundAvg(workBefore.map((e) => e.reflection.emotionalIntensity));
    const afterAvg = roundAvg(workAfter.map((e) => e.reflection.emotionalIntensity));
    if (afterAvg <= beforeAvg - 1) {
      pushItem(items, {
        id: `before-after-sarah-work-${entry.id}`,
        kind: "before_after",
        surface: "calmer",
        title: "Work entries became less intense after the Sarah conversation.",
        detail: `Work-tagged reflections averaged ${beforeAvg}/10 before vs ${afterAvg}/10 after ${formatEntryDate(entry.createdAt).split(",")[0]}.`,
        subject: "Sarah / work",
        subjectType: "entity",
        entryIds: [entry.id, ...workAfter.slice(0, 3).map((e) => e.id)],
        evidence: [evidenceFrom(entry)],
        confidence: 62,
      });
      break;
    }
  }

  const familyEntries = sorted.filter((e) =>
    e.reflection.recurringThemes.some((t) => /family/i.test(t)),
  );
  if (familyEntries.length >= 4) {
    const mid = Math.floor(familyEntries.length / 2);
    const early = familyEntries.slice(0, mid);
    const late = familyEntries.slice(mid);
    const hedgeEarly =
      early.reduce((n, e) => n + (e.transcript.match(HEDGE_RE)?.length ?? 0), 0) /
      early.length;
    const hedgeLate =
      late.reduce((n, e) => n + (e.transcript.match(HEDGE_RE)?.length ?? 0), 0) /
      late.length;
    if (hedgeLate <= hedgeEarly - 0.5) {
      pushItem(items, {
        id: "before-after-family-direct",
        kind: "before_after",
        surface: "changed_over_time",
        title: "You became more direct when discussing family.",
        detail: `Fewer hedging phrases in later family-tagged entries vs earlier ones.`,
        subject: "family",
        subjectType: "theme",
        entryIds: familyEntries.map((e) => e.id),
        evidence: [evidenceFrom(late[0]), evidenceFrom(late[late.length - 1])],
        confidence: 55,
      });
    }
  }

  return items;
}

function detectNarrativeArcs(
  sorted: JournalEntry[],
  themeSeries: SubjectSeries[],
): NarrativeArc[] {
  const arcs: NarrativeArc[] = [];

  for (const series of themeSeries) {
    const intentions = series.points.filter((p) =>
      /\b(i'll|i will|need to|going to)\b/i.test(p.entry.transcript),
    );
    if (intentions.length >= 2 && series.points.length >= intentions.length + 1) {
      arcs.push({
        id: `arc-unresolved-${series.subject}`,
        kind: "unresolved_loop",
        title: `"${series.subject}" keeps returning without closing the loop.`,
        detail: `${intentions.length} entries name an intention around "${series.subject}" — the thread stays open across ${series.points.length} reflections.`,
        entryIds: series.points.map((p) => p.entry.id),
        confidence: 55 + intentions.length * 5,
      });
    }

    const intensities = series.points.map((p) => p.intensity);
    const peak = Math.max(...intensities);
    const peakIdx = intensities.indexOf(peak);
    const afterPeak = intensities.slice(peakIdx + 1);
    if (
      peakIdx > 0 &&
      afterPeak.length >= 2 &&
      afterPeak.every((v) => v <= peak - 1) &&
      roundAvg(afterPeak) <= peak - 1.5
    ) {
      arcs.push({
        id: `arc-completed-${series.subject}`,
        kind: "completed_transition",
        title: `"${series.subject}" peaked, then stayed calmer.`,
        detail: `Peak at ${peak}/10, then ${afterPeak.length} entries averaged ${roundAvg(afterPeak)}/10.`,
        entryIds: series.points.slice(peakIdx).map((p) => p.entry.id),
        confidence: 58,
      });
    }

    let alternations = 0;
    for (let i = 1; i < intensities.length; i += 1) {
      if (Math.abs(intensities[i] - intensities[i - 1]) >= 2) alternations += 1;
    }
    if (alternations >= 2 && series.points.length >= 4) {
      arcs.push({
        id: `arc-cycle-${series.subject}`,
        kind: "recurring_cycle",
        title: `"${series.subject}" cycles between charged and calmer entries.`,
        detail: `${alternations} sharp intensity swings across ${series.points.length} mentions.`,
        entryIds: series.points.map((p) => p.entry.id),
        confidence: 52,
      });
    }
  }

  if (sorted.length >= 5) {
    let maxIdx = 0;
    let maxVal = 0;
    sorted.forEach((e, i) => {
      if (e.reflection.emotionalIntensity > maxVal) {
        maxVal = e.reflection.emotionalIntensity;
        maxIdx = i;
      }
    });
    const after = sorted.slice(maxIdx + 1, maxIdx + 4);
    if (
      after.length >= 2 &&
      after.every((e) => e.reflection.emotionalIntensity <= maxVal - 1.5)
    ) {
      arcs.push({
        id: "arc-recovery-global",
        kind: "recovery_pattern",
        title: "After a high-intensity entry, the next reflections read calmer.",
        detail: `Peak ${maxVal}/10 on ${formatEntryDate(sorted[maxIdx].createdAt)}; following entries averaged ${roundAvg(after.map((e) => e.reflection.emotionalIntensity))}/10.`,
        entryIds: [sorted[maxIdx].id, ...after.map((e) => e.id)],
        confidence: 56,
      });
    }
  }

  return arcs
    .filter((a) => a.confidence >= MIN_CONFIDENCE)
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, 8);
}

function detectIdentityDrift(sorted: JournalEntry[]): IdentityDriftInsight[] {
  if (sorted.length < 4) return [];

  const results: IdentityDriftInsight[] = [];
  const mid = Math.floor(sorted.length / 2);
  const early = sorted.slice(0, mid);
  const late = sorted.slice(mid);

  const hedgeEarly =
    early.reduce((n, e) => n + (e.transcript.match(HEDGE_RE)?.length ?? 0), 0) /
    early.length;
  const hedgeLate =
    late.reduce((n, e) => n + (e.transcript.match(HEDGE_RE)?.length ?? 0), 0) /
    late.length;

  if (hedgeLate >= hedgeEarly + 0.8) {
    results.push({
      id: "identity-more-uncertain",
      title: "Uncertainty language increased in later entries.",
      detail: `Hedges like "maybe" and "I guess" appear more often in the second half of your archive.`,
      direction: "more_uncertain",
      entryIds: late.slice(-3).map((e) => e.id),
      confidence: 54,
    });
  } else if (hedgeEarly >= hedgeLate + 0.8) {
    results.push({
      id: "identity-more-certain",
      title: "Your later entries use fewer softening phrases.",
      detail: `Hedging dropped in the second half of your archive — language reads more settled.`,
      direction: "more_certain",
      entryIds: late.slice(-3).map((e) => e.id),
      confidence: 54,
    });
  }

  const certEarly = early.reduce((n, e) => n + (e.transcript.match(CERTAINTY_RE)?.length ?? 0), 0);
  const certLate = late.reduce((n, e) => n + (e.transcript.match(CERTAINTY_RE)?.length ?? 0), 0);
  if (certLate > certEarly + 1) {
    results.push({
      id: "identity-more-direct",
      title: "Clearer commitment language showed up later.",
      detail: `Phrases like "I will" and "decided" appear more in recent reflections.`,
      direction: "more_direct",
      entryIds: late.filter((e) => CERTAINTY_RE.test(e.transcript)).map((e) => e.id).slice(0, 4),
      confidence: 52,
    });
  }

  const futureEarly = early.reduce((n, e) => n + (e.transcript.match(FUTURE_RE)?.length ?? 0), 0);
  const futureLate = late.reduce((n, e) => n + (e.transcript.match(FUTURE_RE)?.length ?? 0), 0);
  const flatLate = late.reduce((n, e) => n + (e.transcript.match(FLAT_RE)?.length ?? 0), 0);

  if (futureLate > futureEarly + 1 && flatLate === 0) {
    results.push({
      id: "identity-more-hopeful",
      title: "Future-oriented language increased recently.",
      detail: `More "hope", "plan", and forward-looking phrasing in later entries.`,
      direction: "more_hopeful",
      entryIds: late.filter((e) => FUTURE_RE.test(e.transcript)).map((e) => e.id).slice(0, 4),
      confidence: 53,
    });
  } else if (flatLate >= 2 && futureLate < futureEarly) {
    results.push({
      id: "identity-more-flat",
      title: "Flat or stuck language increased in recent entries.",
      detail: `Phrases like "stuck" or "what's the point" appear more often lately.`,
      direction: "more_flat",
      entryIds: late.filter((e) => FLAT_RE.test(e.transcript)).map((e) => e.id).slice(0, 4),
      confidence: 55,
    });
  }

  const selfLabels = buildPhraseMemory(sorted).filter((p) => p.category === "self_label");
  for (const label of selfLabels.slice(0, 2)) {
    results.push({
      id: `identity-label-${label.phrase}`,
      title: `You reach for "${label.phrase}" when describing yourself.`,
      detail: `${label.count} uses across ${label.entryIds.length} entries — a recurring self-label in your words.`,
      direction: label.avgIntensity >= 6 ? "more_uncertain" : "more_certain",
      entryIds: label.entryIds,
      confidence: 50 + label.count * 3,
    });
  }

  return results
    .filter((r) => r.confidence >= MIN_CONFIDENCE)
    .slice(0, 6);
}

function buildPeriodSummaries(sorted: JournalEntry[]): PeriodSummary[] {
  if (sorted.length < 3) return [];

  const summaries: PeriodSummary[] = [];

  const byMonth = new Map<string, JournalEntry[]>();
  const byQuarter = new Map<string, JournalEntry[]>();

  for (const entry of sorted) {
    const mk = monthKey(entry.createdAt);
    const qk = quarterKey(entry.createdAt);
    byMonth.set(mk, [...(byMonth.get(mk) ?? []), entry]);
    byQuarter.set(qk, [...(byQuarter.get(qk) ?? []), entry]);
  }

  for (const [mk, group] of byMonth.entries()) {
    if (group.length < 2) continue;
    const avg = roundAvg(group.map((e) => e.reflection.emotionalIntensity));
    const moods = [...new Set(group.map((e) => e.reflection.mood))];
    const themes = group.flatMap((e) => e.reflection.recurringThemes);
    const themeCounts = new Map<string, number>();
    for (const t of themes) themeCounts.set(t, (themeCounts.get(t) ?? 0) + 1);
    const topTheme = [...themeCounts.entries()].sort((a, b) => b[1] - a[1])[0]?.[0];

    const lines = [
      `${group.length} reflections · average intensity ${avg}/10.`,
      moods.length > 0 ? `Moods tagged: ${moods.slice(0, 4).join(", ")}.` : "",
      topTheme ? `"${topTheme}" surfaced most often.` : "",
    ].filter(Boolean);

    summaries.push({
      id: `month-${mk}`,
      period: "month",
      periodLabel: monthLabel(`${mk}-01`),
      title: `How your thinking shifted in ${monthLabel(`${mk}-01`)}`,
      lines,
      entryIds: group.map((e) => e.id),
    });
  }

  for (const [qk, group] of byQuarter.entries()) {
    if (group.length < 4) continue;
    const firstHalf = group.slice(0, Math.ceil(group.length / 2));
    const secondHalf = group.slice(Math.ceil(group.length / 2));
    const early = roundAvg(firstHalf.map((e) => e.reflection.emotionalIntensity));
    const late = roundAvg(secondHalf.map((e) => e.reflection.emotionalIntensity));
    const direction =
      late <= early - 1 ? "calmer" : late >= early + 1 ? "more charged" : "steady";

    summaries.push({
      id: `quarter-${qk}`,
      period: "quarter",
      periodLabel: quarterLabel(toDayKey(group[0].createdAt)),
      title: `${quarterLabel(toDayKey(group[0].createdAt))}: your archive reads ${direction}.`,
      lines: [
        `${group.length} reflections across the quarter.`,
        `First half averaged ${early}/10; second half ${late}/10.`,
        direction === "calmer"
          ? "Language trended less charged toward the end of the quarter."
          : direction === "more charged"
            ? "Language trended more charged toward the end of the quarter."
            : "Intensity stayed relatively steady quarter-over-quarter.",
      ],
      entryIds: group.map((e) => e.id),
    });
  }

  return summaries
    .sort((a, b) => b.entryIds.length - a.entryIds.length)
    .slice(0, 6);
}

function filterByScope(
  report: Omit<ContinuityReport, "scope" | "hasData" | "generatedAt">,
  entries: JournalEntry[],
  scope: ContinuityScope,
  entryId?: string,
): Omit<ContinuityReport, "scope" | "hasData" | "generatedAt"> {
  if (scope === "archive" || scope === "timeline") return report;

  const recentIds = new Set(
    entries
      .filter((e) => toDayKey(e.createdAt) >= addDaysToKey(toDayKey(new Date().toISOString()), -6))
      .map((e) => e.id),
  );

  const inScope = (ids: string[]) =>
    scope === "weekly" ? ids.some((id) => recentIds.has(id)) : entryId ? ids.includes(entryId) : false;

  const filterItems = (items: ContinuityItem[]) =>
    items.filter((i) => inScope(i.entryIds));

  return {
    items: filterItems(report.items),
    changeMoments: filterItems(report.changeMoments),
    beforeAfter: filterItems(report.beforeAfter),
    narrativeArcs: report.narrativeArcs.filter((a) => inScope(a.entryIds)),
    periodSummaries:
      scope === "weekly"
        ? report.periodSummaries.filter((p) => p.entryIds.some((id) => recentIds.has(id)))
        : report.periodSummaries.filter((p) => entryId && p.entryIds.includes(entryId)),
    identityDrift: report.identityDrift.filter((d) => inScope(d.entryIds)),
  };
}

export { surfaceHeadline };

export interface ContinuityEngineOptions {
  scope?: ContinuityScope;
  entryId?: string;
  limit?: number;
}

/** Build longitudinal continuity report from the full entry archive. */
export function buildContinuityReport(
  entries: JournalEntry[],
  options: ContinuityEngineOptions = {},
): ContinuityReport {
  const scope = options.scope ?? "archive";
  const limit = options.limit ?? 16;

  if (entries.length === 0) {
    return {
      items: [],
      changeMoments: [],
      beforeAfter: [],
      narrativeArcs: [],
      periodSummaries: [],
      identityDrift: [],
      hasData: false,
      generatedAt: new Date().toISOString(),
      scope,
    };
  }

  const sorted = sortedEntries(entries);
  const phrases = buildPhraseMemory(sorted);
  const themeSeries = collectThemeSeries(sorted);
  const entitySeries = collectEntitySeries(sorted);
  const phraseSeries = collectPhraseSeries(phrases, sorted);

  const timelineItems: ContinuityItem[] = [];
  timelineItemsFromSeries(themeSeries, timelineItems);
  timelineItemsFromSeries(entitySeries, timelineItems);
  timelineItemsFromSeries(phraseSeries, timelineItems);

  const changeMoments = detectChangeMoments(sorted);
  const beforeAfter = detectBeforeAfter(sorted, phrases, themeSeries);
  const narrativeArcs = detectNarrativeArcs(sorted, themeSeries);
  const periodSummaries = buildPeriodSummaries(sorted);
  const identityDrift = detectIdentityDrift(sorted);

  const allItems = [...timelineItems, ...changeMoments, ...beforeAfter]
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, limit);

  const raw = {
    items: allItems,
    changeMoments: changeMoments.slice(0, 8),
    beforeAfter: beforeAfter.slice(0, 8),
    narrativeArcs,
    periodSummaries,
    identityDrift,
  };

  const scoped = filterByScope(raw, sorted, scope, options.entryId);

  const hasData =
    scoped.items.length > 0 ||
    scoped.narrativeArcs.length > 0 ||
    scoped.periodSummaries.length > 0 ||
    scoped.identityDrift.length > 0;

  return {
    ...scoped,
    hasData,
    generatedAt: new Date().toISOString(),
    scope,
  };
}

export function getContinuityForEntry(
  entries: JournalEntry[],
  entryId: string,
  limit = 10,
): ContinuityReport {
  return buildContinuityReport(entries, { scope: "entry", entryId, limit });
}

export function getContinuityForWeekly(
  entries: JournalEntry[],
  limit = 10,
): ContinuityReport {
  return buildContinuityReport(entries, { scope: "weekly", limit });
}

export function getTimelineContinuity(
  entries: JournalEntry[],
  limit = 14,
): ContinuityReport {
  return buildContinuityReport(entries, { scope: "timeline", limit });
}
