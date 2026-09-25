import assert from "node:assert/strict";
import test from "node:test";

import {
  aggregateWeeklyRecap,
  synthesizeWeeklyRecap,
  weeklyInputError,
  type WeeklyReflectionEntry,
} from "../src/routes/weekly-reflection.ts";

const now = new Date("2026-09-25T12:00:00.000Z");

function entry(
  entryId: string,
  text: string,
  daysAgo: number,
  embedding?: number[],
): WeeklyReflectionEntry {
  return {
    entryId,
    text,
    timestamp: new Date(now.getTime() - daysAgo * 24 * 60 * 60 * 1000).toISOString(),
    embedding,
  };
}

test("rejects entries that are not an array", () => {
  assert.equal(weeklyInputError({ entries: "nope" }), "entries must be an array.");
  assert.equal(weeklyInputError({ transcripts: {} }), "transcripts must be an array.");
  assert.equal(weeklyInputError({ entries: [], transcripts: [] }), null);
});

test("compares this week with the prior week by embedding similarity", () => {
  const recap = aggregateWeeklyRecap(
    [
      entry("now", "work pressure keeps returning", 1, [1, 0]),
      entry("then", "work pressure last week", 8, [1, 0]),
    ],
    now,
  );
  assert.ok((recap.priorWeekSimilarity ?? 0) > 0.9);
  assert.match(recap.emotionalArc, /continues last week/);
  assert.equal(recap.verbatimCitations[0]?.entryId, "now");
});

test("uses a mock model overlay without dropping citations", async () => {
  const recap = await synthesizeWeeklyRecap(
    [entry("a", "sunday walk", 1)],
    now,
    async () => ({ summary: "A quieter week." }),
  );
  assert.equal(recap.summary, "A quieter week.");
  assert.equal(recap.verbatimCitations[0]?.entryId, "a");
});
