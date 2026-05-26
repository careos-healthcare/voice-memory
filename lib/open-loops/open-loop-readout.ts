import { readLocalEvents } from "@/lib/local-analytics";
import { auditOpenLoopResurfacing } from "@/lib/open-loops/open-loop-resurfacing-lines";
import { OPEN_LOOP_EVENTS } from "@/lib/open-loops/open-loop-observation";
import { getAllOpenLoops } from "@/lib/open-loops/open-loop-storage";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { OpenLoop } from "@/types/open-loop";

export type OpenLoopReadoutHealth = "weak" | "promising" | "strong";

export interface OpenLoopReadoutMetric {
  label: string;
  value: string;
  plain: string;
}

export interface OpenLoopAnchorPhraseRow {
  phrase: string;
  count: number;
}

export interface OpenLoopResurfacingAuditRow {
  openLoopId: string;
  title: string;
  shown: string | null;
  suppressed: string[];
}

export interface OpenLoopsReadoutReport {
  generatedAt: string;
  hasData: boolean;
  scopeNote: string;
  health: OpenLoopReadoutHealth;
  healthHeadline: string;
  metrics: OpenLoopReadoutMetric[];
  topAnchorPhrases: OpenLoopAnchorPhraseRow[];
  loopsWithNoRecurrence: string[];
  resurfacingLinesShown: string[];
  resurfacingAudits: OpenLoopResurfacingAuditRow[];
  suppressedExamples: string[];
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function ratePercent(numerator: number, denominator: number): number {
  if (denominator <= 0) return 0;
  return Math.round((numerator / denominator) * 100);
}

function daysBetween(isoA: string, isoB: string): number {
  const ms = Math.abs(new Date(isoB).getTime() - new Date(isoA).getTime());
  return Math.round(ms / (1000 * 60 * 60 * 24));
}

function countOpenLoopEvents(events: ReturnType<typeof readLocalEvents>) {
  let resurfacingShown = 0;
  let entryReopened = 0;
  let softened = 0;
  let closed = 0;
  let reflectionAfter = 0;
  const resurfacingLines = new Set<string>();
  const reopenedLoopIds = new Set<string>();

  for (const event of events) {
    switch (event.name) {
      case OPEN_LOOP_EVENTS.resurfacingShown:
        resurfacingShown += 1;
        if (event.meta?.line) resurfacingLines.add(event.meta.line);
        break;
      case OPEN_LOOP_EVENTS.entryReopened:
        entryReopened += 1;
        if (event.meta?.openLoopId) reopenedLoopIds.add(event.meta.openLoopId);
        break;
      case OPEN_LOOP_EVENTS.softened:
        softened += 1;
        break;
      case OPEN_LOOP_EVENTS.closed:
        closed += 1;
        break;
      case OPEN_LOOP_EVENTS.reflectionAfterResurface:
        reflectionAfter += 1;
        break;
      default:
        break;
    }
  }

  return {
    resurfacingShown,
    entryReopened,
    softened,
    closed,
    resurfacingLines: [...resurfacingLines],
    reopenedLoopIds: [...reopenedLoopIds],
    reflectionAfter,
  };
}

function avgDaysToNextRelatedReflection(loops: OpenLoop[], entries: ReturnType<typeof getMemoryEligibleEntries>): number | null {
  const gaps: number[] = [];

  for (const loop of loops) {
    const related = entries
      .filter((entry) => loop.relatedEntryIds.includes(entry.id))
      .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
    if (related.length < 2) continue;
    gaps.push(daysBetween(related[0].createdAt, related[1].createdAt));
  }

  if (gaps.length === 0) return null;
  return Math.round(gaps.reduce((sum, gap) => sum + gap, 0) / gaps.length);
}

function countReflectionsAfterResurface(
  loops: OpenLoop[],
  events: ReturnType<typeof readLocalEvents>,
): number {
  const fromEvents = events.filter(
    (event) => event.name === OPEN_LOOP_EVENTS.reflectionAfterResurface,
  ).length;

  const fromArchive = loops.filter((loop) => {
    if (loop.recurrenceCount < 2) return false;
    const history = [...loop.mentionHistory].sort(
      (a, b) => new Date(a).getTime() - new Date(b).getTime(),
    );
    return history.length >= 2;
  }).length;

  return Math.max(fromEvents, fromArchive);
}

function topAnchorPhrases(loops: OpenLoop[], limit = 8): OpenLoopAnchorPhraseRow[] {
  const counts = new Map<string, number>();

  for (const loop of loops) {
    for (const phrase of [loop.strongestAnchorPhrase, ...loop.anchorPhrases]) {
      const key = phrase.trim();
      if (!key || key.length < 8) continue;
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
  }

  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, limit)
    .map(([phrase, count]) => ({ phrase, count }));
}

function buildResurfacingAudits(loops: OpenLoop[]): {
  audits: OpenLoopResurfacingAuditRow[];
  suppressedExamples: string[];
} {
  const audits: OpenLoopResurfacingAuditRow[] = [];
  const suppressedExamples: string[] = [];

  for (const loop of loops.filter((row) => row.status !== "closed")) {
    const audit = auditOpenLoopResurfacing(loop);
    const suppressed = audit.candidates
      .filter((row) => row.suppressed)
      .map((row) => row.line);
    for (const line of suppressed) {
      if (suppressedExamples.length < 12 && !suppressedExamples.includes(line)) {
        suppressedExamples.push(line);
      }
    }
    audits.push({
      openLoopId: loop.openLoopId,
      title: loop.title,
      shown: audit.shown,
      suppressed,
    });
  }

  return { audits, suppressedExamples };
}

function resolveHealth(input: {
  created: number;
  resurfaced: number;
  reopened: number;
  reflectionAfter: number;
}): { health: OpenLoopReadoutHealth; headline: string } {
  if (input.created === 0) {
    return {
      health: "weak",
      headline: "No open loops on this device yet — nothing to validate.",
    };
  }

  if (input.resurfaced > 0 && input.reflectionAfter > 0) {
    return {
      health: "strong",
      headline:
        "Loop resurfaced and the user recorded again — continuity is compounding on this device.",
    };
  }

  if (input.resurfaced > 0 && input.reopened > 0) {
    return {
      health: "promising",
      headline: "Loops are resurfacing and entries are being reopened — revisit is happening.",
    };
  }

  return {
    health: "weak",
    headline: "Loops were created but rarely resurfaced or revisited — continuity is not sticking yet.",
  };
}

export function buildOpenLoopsReadoutReport(): OpenLoopsReadoutReport {
  if (!isBrowser()) {
    return emptyReport("Open loops readout runs in the browser only.");
  }

  const loops = getAllOpenLoops();
  const entries = getMemoryEligibleEntries();
  const events = readLocalEvents();
  const eventCounts = countOpenLoopEvents(events);

  const eligibleEntries = entries.filter((entry) => entry.transcript?.trim());
  const sourceEntryIds = new Set(loops.map((loop) => loop.sourceEntryId));
  const createRate = ratePercent(sourceEntryIds.size, eligibleEntries.length);

  const resurfacedFromData = loops.filter(
    (loop) => loop.mentionHistory.length > 1 || loop.recurrenceCount > 1,
  ).length;
  const resurfaced = Math.max(eventCounts.resurfacingShown, resurfacedFromData);

  const reopenedFromData = loops.filter((loop) =>
    loop.relatedEntryIds.some((id) => {
      const entry = entries.find((row) => row.id === id);
      return entry && entry.id !== loop.sourceEntryId;
    }),
  ).length;
  const reopened = Math.max(eventCounts.entryReopened, reopenedFromData);

  const closedOrSoftened =
    loops.filter((loop) => loop.status === "closed").length +
    loops.filter((loop) => loop.status === "softened").length;

  const reflectionAfter = countReflectionsAfterResurface(loops, events);
  const avgDays = avgDaysToNextRelatedReflection(loops, entries);
  const noRecurrence = loops
    .filter((loop) => loop.recurrenceCount <= 1 && loop.relatedEntryIds.length <= 1)
    .map((loop) => loop.title);

  const computedLines = loops
    .filter((loop) => loop.status !== "closed")
    .map((loop) => auditOpenLoopResurfacing(loop).shown)
    .filter((line): line is string => Boolean(line));

  const resurfacingLinesShown = [
    ...new Set([...eventCounts.resurfacingLines, ...computedLines]),
  ];

  const { audits, suppressedExamples } = buildResurfacingAudits(loops);

  const { health, headline } = resolveHealth({
    created: loops.length,
    resurfaced,
    reopened,
    reflectionAfter,
  });

  const metrics: OpenLoopReadoutMetric[] = [
    {
      label: "Open loops created",
      value: String(loops.length),
      plain: `${loops.length} loop${loops.length === 1 ? "" : "s"} saved locally (all statuses).`,
    },
    {
      label: "Entries that created a loop",
      value: `${createRate}%`,
      plain: `${sourceEntryIds.size} of ${eligibleEntries.length} transcript entries spawned an open loop.`,
    },
    {
      label: "Loops resurfaced",
      value: String(resurfaced),
      plain: `${resurfaced} loop${resurfaced === 1 ? "" : "s"} with repeat mentions or resurfacing_shown events.`,
    },
    {
      label: "Loops reopened / revisited",
      value: String(reopened),
      plain: `${reopened} loop${reopened === 1 ? "" : "s"} linked to another reflection or entry_reopened events (${eventCounts.entryReopened} events).`,
    },
    {
      label: "Closed or softened",
      value: String(closedOrSoftened),
      plain: `${closedOrSoftened} loop${closedOrSoftened === 1 ? "" : "s"} marked softened or closed (${eventCounts.softened} softened, ${eventCounts.closed} closed events).`,
    },
    {
      label: "Reflections after resurfacing",
      value: String(reflectionAfter),
      plain:
        reflectionAfter === 0
          ? "No second related reflection after a loop yet."
          : `${reflectionAfter} loop${reflectionAfter === 1 ? "" : "s"} gained another related reflection after the thread started.`,
    },
    {
      label: "Avg days to next related reflection",
      value: avgDays === null ? "—" : String(avgDays),
      plain:
        avgDays === null
          ? "Need at least two linked reflections per loop to measure spacing."
          : `Average ${avgDays} days between first and next linked reflection.`,
    },
  ];

  return {
    generatedAt: new Date().toISOString(),
    hasData: loops.length > 0 || events.some((event) => event.name.startsWith("open_loop_")),
    scopeNote:
      "Debug only — local loop storage plus voicememory_local_events. Not shown in product UI.",
    health,
    healthHeadline: headline,
    metrics,
    topAnchorPhrases: topAnchorPhrases(loops),
    loopsWithNoRecurrence: noRecurrence.slice(0, 12),
    resurfacingLinesShown,
    resurfacingAudits: audits,
    suppressedExamples,
  };
}

function emptyReport(scopeNote: string): OpenLoopsReadoutReport {
  return {
    generatedAt: new Date().toISOString(),
    hasData: false,
    scopeNote,
    health: "weak",
    healthHeadline: "No local data to read.",
    metrics: [],
    topAnchorPhrases: [],
    loopsWithNoRecurrence: [],
    resurfacingLinesShown: [],
    resurfacingAudits: [],
    suppressedExamples: [],
  };
}

export function openLoopHealthTone(
  health: OpenLoopReadoutHealth,
): "neutral" | "warning" | "positive" {
  if (health === "strong") return "positive";
  if (health === "promising") return "neutral";
  return "warning";
}
