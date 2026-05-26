import { pickOpenLoopResurfacingLine } from "@/lib/open-loops/open-loop-resurfacing-lines";
import {
  getActiveOpenLoops,
  recordOpenLoopMentioned,
} from "@/lib/open-loops/open-loop-storage";
import type { OpenLoop } from "@/types/open-loop";

/** Pick loops that merit quiet continuity surfacing — no productivity framing. */
export function pickOpenLoopsToResurface(limit = 2, now = Date.now()): OpenLoop[] {
  const active = getActiveOpenLoops();
  if (active.length === 0) return [];

  const scored = active
    .map((loop) => ({
      loop,
      line: pickOpenLoopResurfacingLine(loop, now),
    }))
    .filter((row) => Boolean(row.line))
    .map((row) => {
      const ageDays =
        (now - new Date(row.loop.lastMentionedAt).getTime()) / (1000 * 60 * 60 * 24);
      const staleBoost = ageDays >= 3 ? 10 : ageDays >= 1 ? 4 : 0;
      const recurrenceBoost = row.loop.recurrenceCount >= 2 ? 6 : 0;
      return {
        loop: row.loop,
        score: staleBoost + recurrenceBoost,
      };
    });

  return scored
    .sort((a, b) => b.score - a.score || b.loop.updatedAt.localeCompare(a.loop.updatedAt))
    .slice(0, limit)
    .map((row) => row.loop);
}

/** Record mention only when a line is actually shown — silence-first otherwise. */
export function markMentionedOpenLoops(loops: OpenLoop[]): void {
  for (const loop of loops) {
    if (pickOpenLoopResurfacingLine(loop)) {
      recordOpenLoopMentioned(loop.openLoopId);
    }
  }
}
