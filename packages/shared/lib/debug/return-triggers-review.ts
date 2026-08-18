import {
  buildReturnTriggerRows,
  countReturnTriggerEvents,
  RETURN_TRIGGER_EVENTS,
} from "@/lib/retention/return-triggers";
import type {
  ReturnTriggerCategorySummary,
  ReturnTriggerDebugReport,
  ReturnTriggerEventName,
  ReturnTriggerKind,
} from "@/types/return-triggers";

const CATEGORY_SPECS: Array<{
  kind: ReturnTriggerKind | "voluntary";
  eventName: ReturnTriggerEventName;
}> = [
  { kind: "photo", eventName: RETURN_TRIGGER_EVENTS.returnAfterPhoto },
  { kind: "revisit", eventName: RETURN_TRIGGER_EVENTS.returnAfterRevisit },
  { kind: "roundup", eventName: RETURN_TRIGGER_EVENTS.returnAfterRoundup },
  { kind: "territory", eventName: RETURN_TRIGGER_EVENTS.returnAfterTerritory },
  { kind: "silence", eventName: RETURN_TRIGGER_EVENTS.returnAfterSilence },
  { kind: "backup", eventName: RETURN_TRIGGER_EVENTS.returnAfterBackup },
  { kind: "archive_export", eventName: RETURN_TRIGGER_EVENTS.returnAfterArchiveExport },
  { kind: "first_callback", eventName: RETURN_TRIGGER_EVENTS.returnAfterFirstCallback },
  { kind: "prompt", eventName: RETURN_TRIGGER_EVENTS.returnAfterPrompt },
  { kind: "voluntary", eventName: RETURN_TRIGGER_EVENTS.returnWithoutPrompt },
];

function median(values: number[]): number | null {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? Math.round((sorted[mid - 1] + sorted[mid]) / 2)
    : sorted[mid];
}

function rate(count: number, total: number): number {
  if (total === 0) return 0;
  return Math.round((count / total) * 100);
}

function classifyStrength(
  count: number,
  reflectionRate: number,
  revisitRate: number,
): ReturnTriggerCategorySummary["strength"] {
  if (count === 0) return "none";
  const payoff = reflectionRate + revisitRate;
  if (count >= 3 && payoff >= 40) return "strong";
  if (count >= 2 && payoff >= 20) return "moderate";
  if (count >= 3 && payoff < 10) return "noisy";
  return "weak";
}

function summarizeCategory(
  kind: ReturnTriggerKind | "voluntary",
  eventName: ReturnTriggerEventName,
): ReturnTriggerCategorySummary {
  const rows = buildReturnTriggerRows().filter((row) => row.eventName === eventName);
  const hours = rows
    .map((row) => row.hoursSinceTrigger ?? row.hoursSinceLastOpen)
    .filter((value): value is number => value !== null);
  const reflectionCount = rows.filter((row) => row.ledToReflection).length;
  const revisitCount = rows.filter((row) => row.ledToRevisit).length;
  const exportCount = rows.filter((row) => row.ledToExportOrBackup).length;
  const reflectionRate = rate(reflectionCount, rows.length);
  const revisitRate = rate(revisitCount, rows.length);
  const exportOrBackupRate = rate(exportCount, rows.length);

  return {
    kind,
    eventName,
    count: rows.length,
    medianHoursToReturn: median(hours),
    reflectionRate,
    revisitRate,
    exportOrBackupRate,
    strength: classifyStrength(rows.length, reflectionRate, revisitRate),
  };
}

export function buildReturnTriggersDebugReport(): ReturnTriggerDebugReport {
  const instrumentation = countReturnTriggerEvents();
  const recentReturns = buildReturnTriggerRows();
  const categories = CATEGORY_SPECS.map(({ kind, eventName }) =>
    summarizeCategory(kind, eventName),
  );
  const attributed = categories.filter((row) => row.kind !== "voluntary");
  const strongestTriggers = [...attributed]
    .filter((row) => row.count > 0)
    .sort((a, b) => {
      const scoreA = a.reflectionRate + a.revisitRate + a.count * 5;
      const scoreB = b.reflectionRate + b.revisitRate + b.count * 5;
      return scoreB - scoreA;
    })
    .slice(0, 4);
  const weakOrNoisyTriggers = categories.filter(
    (row) => row.strength === "weak" || row.strength === "noisy",
  );

  const promptDrivenCount = instrumentation[RETURN_TRIGGER_EVENTS.returnAfterPrompt] ?? 0;
  const voluntaryCount = instrumentation[RETURN_TRIGGER_EVENTS.returnWithoutPrompt] ?? 0;
  const totalReturns = Object.values(instrumentation).reduce((sum, count) => sum + count, 0);

  const byKind = (kind: ReturnTriggerKind | "voluntary") => {
    const spec = CATEGORY_SPECS.find((row) => row.kind === kind);
    if (!spec) {
      return summarizeCategory("voluntary", RETURN_TRIGGER_EVENTS.returnWithoutPrompt);
    }
    return summarizeCategory(spec.kind, spec.eventName);
  };

  return {
    generatedAt: new Date().toISOString(),
    hasData: totalReturns > 0 || readAnchorsCount() > 0,
    totalReturns,
    instrumentation,
    strongestTriggers,
    weakOrNoisyTriggers,
    promptDrivenCount,
    voluntaryCount,
    silenceDriven: byKind("silence"),
    photoDriven: byKind("photo"),
    territoryDriven: byKind("territory"),
    revisitDriven: byKind("revisit"),
    recentReturns,
  };
}

function readAnchorsCount(): number {
  if (typeof window === "undefined") return 0;
  try {
    const raw = localStorage.getItem("voicememory_return_trigger_anchors");
    if (!raw) return 0;
    const parsed = JSON.parse(raw) as unknown[];
    return Array.isArray(parsed) ? parsed.length : 0;
  } catch {
    return 0;
  }
}
