import { readLocalEvents } from "@/lib/local-analytics";
import { OPEN_LOOP_EVENTS } from "@/lib/open-loops/open-loop-observation";
import { CALLBACK_LEARNING_EVENTS } from "@/lib/revisit/callback-learning";
import { getResurfacingFatigueRecords } from "@/lib/memory/resurfacing-priority";
import { isGenericResurfacing } from "@/lib/resurfacing/genericity-filter";
import { ratePercent } from "@/lib/behavior/helpers";
import type { CopyEffectivenessRow } from "@/types/behavior-truth";
import type { LocalAnalyticsEvent } from "@/lib/local-analytics";

function previewLine(text: string, max = 72): string {
  const trimmed = text.trim();
  if (trimmed.length <= max) return trimmed;
  return `${trimmed.slice(0, max - 1)}…`;
}

function lineKey(text: string): string {
  return text.trim().toLowerCase().slice(0, 120);
}

function verdictFor(
  shown: number,
  openRate: number,
  reflectionRate: number,
  generic: boolean,
): CopyEffectivenessRow["verdict"] {
  if (shown < 2) return "ignored";
  if (generic && openRate < 15) return "weak";
  if (reflectionRate >= 20 || openRate >= 30) return "strong";
  if (openRate < 8 && reflectionRate < 5) return "ignored";
  return "weak";
}

export function computeCopyEffectiveness(events: LocalAnalyticsEvent[]): CopyEffectivenessRow[] {
  const byLine = new Map<
    string,
    { preview: string; shown: number; opened: number; reflectionsAfter: number; generic: boolean }
  >();

  for (const event of events) {
    if (event.name === OPEN_LOOP_EVENTS.resurfacingShown) {
      const line = event.meta?.line ?? "";
      if (!line) continue;
      const key = lineKey(line);
      const row = byLine.get(key) ?? {
        preview: previewLine(line),
        shown: 0,
        opened: 0,
        reflectionsAfter: 0,
        generic: isGenericResurfacing(line),
      };
      row.shown += 1;
      byLine.set(key, row);
    }
  }

  for (const event of events) {
    if (event.name === OPEN_LOOP_EVENTS.entryReopened && event.meta?.openLoopId) {
      const loopId = event.meta.openLoopId;
      const match = events.filter(
        (e) =>
          e.name === OPEN_LOOP_EVENTS.resurfacingShown && e.meta?.openLoopId === loopId,
      );
      const lastLine = match[match.length - 1]?.meta?.line;
      if (lastLine) {
        const key = lineKey(lastLine);
        const row = byLine.get(key);
        if (row) row.opened += 1;
      }
    }
    if (event.name === OPEN_LOOP_EVENTS.reflectionAfterResurface) {
      const loopEvents = events.filter(
        (e) =>
          e.name === OPEN_LOOP_EVENTS.resurfacingShown &&
          e.meta?.openLoopId === event.meta?.openLoopId,
      );
      const lastLine = loopEvents[loopEvents.length - 1]?.meta?.line;
      if (lastLine) {
        const key = lineKey(lastLine);
        const row = byLine.get(key);
        if (row) row.reflectionsAfter += 1;
      }
    }
  }

  const noteOutcomes = new Map<string, { opened: number; reflection: number }>();
  for (const event of events) {
    const noteId = event.meta?.noteId;
    if (!noteId) continue;
    const row = noteOutcomes.get(noteId) ?? { opened: 0, reflection: 0 };
    if (
      event.name === CALLBACK_LEARNING_EVENTS.opened ||
      event.name === CALLBACK_LEARNING_EVENTS.reread
    ) {
      row.opened += 1;
    }
    if (event.name === CALLBACK_LEARNING_EVENTS.reflectionAfter) {
      row.reflection += 1;
    }
    noteOutcomes.set(noteId, row);
  }

  for (const record of getResurfacingFatigueRecords()) {
    const text = record.textKey;
    const key = lineKey(text);
    const outcomes = noteOutcomes.get(record.noteId) ?? { opened: 0, reflection: 0 };
    const row = byLine.get(key) ?? {
      preview: previewLine(text),
      shown: 0,
      opened: 0,
      reflectionsAfter: 0,
      generic: isGenericResurfacing(text),
    };
    row.shown += 1;
    row.opened += outcomes.opened > 0 ? 1 : 0;
    row.reflectionsAfter += outcomes.reflection > 0 ? 1 : 0;
    byLine.set(key, row);
  }

  const rows: CopyEffectivenessRow[] = [];
  for (const [lineKeyValue, agg] of byLine) {
    const openRate = ratePercent(agg.opened, agg.shown);
    const reflectionRate = ratePercent(agg.reflectionsAfter, agg.shown);
    const verdict = verdictFor(agg.shown, openRate, reflectionRate, agg.generic);
    const base = {
      lineKey: lineKeyValue,
      preview: agg.preview,
      shown: agg.shown,
      opened: agg.opened,
      reflectionsAfter: agg.reflectionsAfter,
      openRate,
      reflectionRate,
      generic: agg.generic,
      verdict,
    };
    rows.push({
      ...base,
      plain:
        verdict === "strong"
          ? `This line often leads to opens or another reflection: “${agg.preview}”.`
          : verdict === "weak"
            ? `Generic or low-return line: “${agg.preview}”.`
            : `Often ignored: “${agg.preview}”.`,
    });
  }

  return rows.sort((a, b) => b.reflectionRate - a.reflectionRate || b.openRate - a.openRate);
}

export function pickStrongestCopy(rows: CopyEffectivenessRow[]): CopyEffectivenessRow[] {
  return rows.filter((row) => row.verdict === "strong").slice(0, 5);
}

export function pickWeakCopy(rows: CopyEffectivenessRow[]): CopyEffectivenessRow[] {
  return rows.filter((row) => row.verdict === "weak" || row.generic).slice(0, 5);
}
