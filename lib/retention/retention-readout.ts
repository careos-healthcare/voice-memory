import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import {
  LAUNCH_EVENTS,
  hasLocalEvent,
  readLocalEvents,
} from "@/lib/local-analytics";
import { buildRepeatedThemeReport } from "@/lib/patterns/repeated-themes";
import { hasConcreteResurfacingEvidence } from "@/lib/resurfacing/evidence-engine";
import {
  isGenericResurfacing,
  passesResurfacingGenericityGate,
} from "@/lib/resurfacing/genericity-filter";
import {
  CALLBACK_LEARNING_EVENTS,
  readCallbackLearningEvents,
} from "@/lib/revisit/callback-learning";
import { collectResurfacingConfidenceCandidates } from "@/lib/revisit/resurfacing-confidence";
import { assessResurfacingWhyNow } from "@/lib/revisit/resurfacing-why-now";
import {
  SESSION_RETENTION_EVENTS,
  readSessionRetentionSnapshot,
} from "@/lib/retention/session-retention";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export type RetentionHealth = "weak" | "promising" | "strong";

export interface RetentionReadoutMetric {
  label: string;
  value: string;
  plain: string;
  failure?: boolean;
}

export interface RetentionEvidencePatternRow {
  label: string;
  count: number;
  example: string | null;
}

export interface RetentionReadoutFailures {
  suppressedGenericCount: number;
  suppressedExamples: string[];
  neverOpenedCount: number;
  neverOpenedIds: string[];
  churnedAfterFirstReflection: boolean;
  lines: string[];
}

export interface RetentionReadoutReport {
  generatedAt: string;
  hasData: boolean;
  scopeNote: string;
  health: RetentionHealth;
  healthHeadline: string;
  metrics: RetentionReadoutMetric[];
  evidencePatterns: RetentionEvidencePatternRow[];
  remembersMe: RetentionReadoutMetric[];
  failures: RetentionReadoutFailures;
}

const CHURN_IDLE_DAYS = 14;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function ratePercent(numerator: number, denominator: number): number {
  if (denominator <= 0) return 0;
  return Math.round((numerator / denominator) * 100);
}

function countCallbackEngagement(events: ReturnType<typeof readLocalEvents>) {
  const shownIds = new Set<string>();
  const openedIds = new Set<string>();
  const openCountByNote = new Map<string, number>();
  let shown = 0;
  let opened = 0;
  let reread = 0;
  let reflectionAfter = 0;
  let returnAfter = 0;

  for (const event of events) {
    const noteId = event.meta?.noteId;
    switch (event.name) {
      case CALLBACK_LEARNING_EVENTS.shown:
        shown += 1;
        if (noteId) shownIds.add(noteId);
        break;
      case CALLBACK_LEARNING_EVENTS.opened:
        opened += 1;
        if (noteId) {
          openedIds.add(noteId);
          openCountByNote.set(noteId, (openCountByNote.get(noteId) ?? 0) + 1);
        }
        break;
      case CALLBACK_LEARNING_EVENTS.reread:
        reread += 1;
        if (noteId) {
          openCountByNote.set(noteId, (openCountByNote.get(noteId) ?? 0) + 1);
        }
        break;
      case CALLBACK_LEARNING_EVENTS.reflectionAfter:
        reflectionAfter += 1;
        break;
      case CALLBACK_LEARNING_EVENTS.returnAfter:
        returnAfter += 1;
        break;
      default:
        break;
    }
  }

  const openedAmongShown = [...openedIds].filter((id) => shownIds.has(id)).length;
  const openedTwice = [...openCountByNote.values()].filter((count) => count >= 2).length;
  const neverOpened = [...shownIds].filter((id) => !openedIds.has(id));

  return {
    shown,
    opened,
    reread,
    reflectionAfter,
    returnAfter,
    uniqueShown: shownIds.size,
    uniqueOpenedAmongShown: openedAmongShown,
    openedTwice,
    neverOpened,
    shownIds,
  };
}

function buildEvidencePatterns(entries: JournalEntry[]): RetentionEvidencePatternRow[] {
  const report = buildRepeatedThemeReport(entries);
  const rows: RetentionEvidencePatternRow[] = [];

  const waiting = report.phrases.filter((row) => /\bwait(ing)?\b/i.test(row.phrase));
  if (waiting.length > 0) {
    rows.push({
      label: "Repeated waiting",
      count: waiting.length,
      example: waiting[0]?.phrase.slice(0, 72) ?? null,
    });
  }

  const family = report.entities.filter((row) =>
    /\b(mum|dad|mother|father|family|sister|brother)\b/i.test(row.name),
  );
  if (family.length > 0) {
    rows.push({
      label: "Repeated family references",
      count: family.length,
      example: family[0]?.name ?? null,
    });
  }

  const anxietyPhrases = report.phrases.filter((row) => /\b(anxious|anxiety|panic|worried)\b/i.test(row.phrase));
  const anxietyConcerns = report.concerns.filter((row) =>
    /\b(anxious|anxiety|panic|worried|stress)\b/i.test(row.concern),
  );
  if (anxietyPhrases.length + anxietyConcerns.length > 0) {
    const example =
      anxietyPhrases[0]?.phrase ?? anxietyConcerns[0]?.concern ?? null;
    rows.push({
      label: "Repeated anxiety wording",
      count: anxietyPhrases.length + anxietyConcerns.length,
      example: example ? example.slice(0, 72) : null,
    });
  }

  const people = report.entities.filter((row) => row.type === "person");
  if (people.length > 0) {
    rows.push({
      label: "Repeated person names",
      count: people.length,
      example: people[0]?.name ?? null,
    });
  }

  if (report.phrases.length > 0 && rows.every((row) => row.label !== "Repeated exact phrases")) {
    rows.push({
      label: "Repeated exact phrases",
      count: report.phrases.length,
      example: report.phrases[0]?.phrase.slice(0, 72) ?? null,
    });
  }

  return rows.sort((a, b) => b.count - a.count).slice(0, 6);
}

function countGenericityRejections(entries: JournalEntry[]): {
  rejected: number;
  candidates: number;
  examples: string[];
} {
  const candidates = collectResurfacingConfidenceCandidates(entries);
  const examples: string[] = [];
  let rejected = 0;

  for (const note of candidates) {
    const whyNow = assessResurfacingWhyNow(note, entries);
    const blocked =
      isGenericResurfacing(note.text) ||
      !hasConcreteResurfacingEvidence(note, entries) ||
      !passesResurfacingGenericityGate(note.text, note, {
        evidenceBacked: whyNow.evidenceBacked,
      });
    if (blocked) {
      rejected += 1;
      if (examples.length < 5 && note.text.trim()) {
        examples.push(note.text.trim().slice(0, 88));
      }
    }
  }

  return { rejected, candidates: candidates.length, examples };
}

function estimateReflectionsBeforeChurn(
  entries: JournalEntry[],
  recordedSecond: boolean,
): { value: number | null; plain: string } {
  if (entries.length === 0) {
    return { value: null, plain: "No reflections saved yet." };
  }

  const sorted = [...entries].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
  const lastAt = sorted[0]?.createdAt;
  const daysIdle = lastAt
    ? daysBetweenKeys(toDayKey(lastAt), todayKey())
    : 0;

  if (entries.length === 1 && !recordedSecond) {
    return {
      value: 1,
      plain: "Churn estimate: stopped after the first reflection (local).",
    };
  }

  if (daysIdle >= CHURN_IDLE_DAYS) {
    return {
      value: entries.length,
      plain: `Churn estimate: ${entries.length} reflection${entries.length === 1 ? "" : "s"} before going quiet (${daysIdle}d since last).`,
    };
  }

  return {
    value: null,
    plain: `Still active locally — ${entries.length} reflection${entries.length === 1 ? "" : "s"}, last ${daysIdle}d ago.`,
  };
}

function computeHealth(input: {
  secondReflectionRate: number;
  day2Returned: boolean;
  callbackOpenRate: number;
  revisitAfterCallbackRate: number;
  hasSecondReflection: boolean;
}): { health: RetentionHealth; headline: string } {
  let score = 0;
  if (input.hasSecondReflection) score += 2;
  if (input.day2Returned) score += 2;
  if (input.callbackOpenRate >= 35) score += 2;
  else if (input.callbackOpenRate >= 15) score += 1;
  if (input.revisitAfterCallbackRate >= 25) score += 2;
  else if (input.revisitAfterCallbackRate >= 10) score += 1;

  if (score >= 6) {
    return {
      health: "strong",
      headline: "Retention signals look strong on this device — still not a cohort.",
    };
  }
  if (score >= 3) {
    return {
      health: "promising",
      headline: "Some retention signal — worth watching, not proven yet.",
    };
  }
  return {
    health: "weak",
    headline: "Retention is weak on this device — fix before scaling testers.",
  };
}

/** Brutally honest local retention readout — single device only. */
export function buildRetentionReadoutReport(): RetentionReadoutReport {
  if (!isBrowser()) {
    return emptyReport("Browser only — open on a device with local data.");
  }

  const entries = getMemoryEligibleEntries();
  const events = readLocalEvents();
  const session = readSessionRetentionSnapshot();
  const callback = countCallbackEngagement(events);
  const genericity = countGenericityRejections(entries);

  const hasSecondReflection =
    entries.length >= 2 ||
    hasLocalEvent(LAUNCH_EVENTS.secondReflectionCreated) ||
    Boolean(session.onceFlags[SESSION_RETENTION_EVENTS.secondSessionStarted]);

  const secondReflectionRate = hasSecondReflection ? 100 : 0;

  const day2Returned =
    Boolean(session.onceFlags[SESSION_RETENTION_EVENTS.day2Return]) ||
    hasLocalEvent(SESSION_RETENTION_EVENTS.day2Return) ||
    events.some((event) => event.name === SESSION_RETENTION_EVENTS.day2Return);

  const callbackOpenRate = ratePercent(
    callback.uniqueOpenedAmongShown,
    callback.uniqueShown,
  );
  const reflectionAfterRate = ratePercent(
    callback.reflectionAfter,
    Math.max(callback.opened, 1),
  );
  const revisitAfterCallbackRate = ratePercent(
    callback.returnAfter,
    Math.max(callback.opened, 1),
  );

  const { health, headline } = computeHealth({
    secondReflectionRate,
    day2Returned,
    callbackOpenRate,
    revisitAfterCallbackRate,
    hasSecondReflection,
  });

  const churn = estimateReflectionsBeforeChurn(entries, hasSecondReflection);

  const repeatEngagement = events.filter(
    (event) => event.name === CALLBACK_LEARNING_EVENTS.shown,
  ).length;

  const metrics: RetentionReadoutMetric[] = [
    {
      label: "Second reflection",
      value: hasSecondReflection ? "Yes" : "No",
      plain: hasSecondReflection
        ? "This device recorded more than one reflection."
        : "Only one reflection on this device so far.",
      failure: !hasSecondReflection,
    },
    {
      label: "Day-2 return",
      value: day2Returned ? "Yes" : "No",
      plain: day2Returned
        ? "Day-2 return fired (session flag or day_2_return event)."
        : "No day-2 return signal yet.",
      failure: !day2Returned && entries.length > 0,
    },
    {
      label: "Callback open rate",
      value: `${callbackOpenRate}%`,
      plain:
        callback.uniqueShown === 0
          ? "No callbacks shown yet — nothing to open."
          : `${callbackOpenRate}% of shown callbacks were opened (${callback.uniqueOpenedAmongShown}/${callback.uniqueShown} unique).`,
      failure: callback.uniqueShown > 0 && callbackOpenRate < 20,
    },
    {
      label: "Reflection after callback",
      value: String(callback.reflectionAfter),
      plain:
        callback.opened === 0
          ? "No opens — reflection-after-callback not measurable."
          : `${reflectionAfterRate}% of opens led to reflection_after_callback (${callback.reflectionAfter}/${callback.opened} opens).`,
      failure: callback.opened > 0 && callback.reflectionAfter === 0,
    },
    {
      label: "Reflections before churn (estimate)",
      value: churn.value === null ? "—" : String(churn.value),
      plain: churn.plain,
      failure: churn.value === 1,
    },
    {
      label: "Generic callbacks rejected",
      value: `${genericity.rejected}`,
      plain:
        genericity.candidates === 0
          ? "No resurfacing candidates in archive yet."
          : `${genericity.rejected} of ${genericity.candidates} candidates blocked by evidence/genericity filters (${ratePercent(genericity.rejected, genericity.candidates)}%).`,
    },
  ];

  const remembersMe: RetentionReadoutMetric[] = [
    {
      label: "Callbacks opened twice+",
      value: String(callback.openedTwice),
      plain:
        callback.openedTwice === 0
          ? "No callback opened more than once."
          : `${callback.openedTwice} callback${callback.openedTwice === 1 ? "" : "s"} opened or re-read twice.`,
    },
    {
      label: "Revisit after callback",
      value: String(callback.returnAfter),
      plain:
        callback.returnAfter === 0
          ? "No return_after_callback events."
          : `${callback.returnAfter} return-after-callback signal${callback.returnAfter === 1 ? "" : "s"}.`,
    },
    {
      label: "Repeat resurfacing engagement",
      value: String(repeatEngagement),
      plain: `${repeatEngagement} callback_shown events in local log (repeated surfacing).`,
    },
  ];

  const failureLines: string[] = [];
  if (!hasSecondReflection && entries.length > 0) {
    failureLines.push("User likely churned after the first reflection.");
  }
  if (genericity.rejected > 0) {
    failureLines.push(
      `${genericity.rejected} generic or weak callbacks were suppressed before show.`,
    );
  }
  if (callback.neverOpened.length > 0) {
    failureLines.push(
      `${callback.neverOpened.length} shown callback${callback.neverOpened.length === 1 ? "" : "s"} never opened.`,
    );
  }
  if (callback.uniqueShown > 0 && callbackOpenRate < 15) {
    failureLines.push("Callbacks are being shown but rarely opened.");
  }

  const hasData =
    entries.length > 0 || events.length > 0 || readCallbackLearningEvents(1).length > 0;

  return {
    generatedAt: new Date().toISOString(),
    hasData,
    scopeNote:
      "Single browser only. Percentages are this device, not a multi-user cohort. No new tracking.",
    health,
    healthHeadline: headline,
    metrics,
    evidencePatterns: buildEvidencePatterns(entries),
    remembersMe,
    failures: {
      suppressedGenericCount: genericity.rejected,
      suppressedExamples: genericity.examples,
      neverOpenedCount: callback.neverOpened.length,
      neverOpenedIds: callback.neverOpened.slice(0, 8),
      churnedAfterFirstReflection: entries.length === 1 && !hasSecondReflection,
      lines: failureLines,
    },
  };
}

function emptyReport(scopeNote: string): RetentionReadoutReport {
  return {
    generatedAt: new Date().toISOString(),
    hasData: false,
    scopeNote,
    health: "weak",
    healthHeadline: "No local data to read.",
    metrics: [],
    evidencePatterns: [],
    remembersMe: [],
    failures: {
      suppressedGenericCount: 0,
      suppressedExamples: [],
      neverOpenedCount: 0,
      neverOpenedIds: [],
      churnedAfterFirstReflection: false,
      lines: [],
    },
  };
}

export function healthTone(
  health: RetentionHealth,
): "neutral" | "warning" | "positive" {
  if (health === "strong") return "positive";
  if (health === "promising") return "neutral";
  return "warning";
}
