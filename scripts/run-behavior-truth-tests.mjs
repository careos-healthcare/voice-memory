#!/usr/bin/env node
import assert from "node:assert/strict";

import { computeBehaviorFunnels } from "../lib/behavior/funnels.ts";
import { computeReturnTiming, computeUserReturnSegments } from "../lib/behavior/return-analysis.ts";
import { computeSurfaceEffectiveness } from "../lib/behavior/surface-effectiveness.ts";
import { computeCopyEffectiveness } from "../lib/behavior/copy-effectiveness.ts";
import { computeProductPressureWarnings } from "../lib/behavior/product-pressure.ts";
import { buildBehaviorInsightSummary } from "../lib/behavior/insight-summary.ts";
import { ratePercent, medianHours } from "../lib/behavior/helpers.ts";
import { LAUNCH_EVENTS } from "../lib/local-analytics.ts";
import { CALLBACK_LEARNING_EVENTS } from "../lib/revisit/callback-learning.ts";
import { OPEN_LOOP_EVENTS } from "../lib/open-loops/open-loop-observation.ts";

assert.equal(ratePercent(2, 10), 20);
assert.equal(medianHours([4, 8, 12]), 8);

const events = [
  { name: LAUNCH_EVENTS.firstReflectionCreated, at: "2026-01-01T10:00:00.000Z" },
  { name: LAUNCH_EVENTS.secondReflectionCreated, at: "2026-01-02T10:00:00.000Z" },
  {
    name: CALLBACK_LEARNING_EVENTS.shown,
    at: "2026-01-02T11:00:00.000Z",
    meta: { surface: "homepage", noteId: "n1" },
  },
  {
    name: CALLBACK_LEARNING_EVENTS.opened,
    at: "2026-01-02T11:05:00.000Z",
    meta: { surface: "homepage", noteId: "n1" },
  },
  {
    name: OPEN_LOOP_EVENTS.resurfacingShown,
    at: "2026-01-03T10:00:00.000Z",
    meta: { openLoopId: "l1", line: "You said you were still scared" },
  },
];

const entries = [
  { id: "e1", createdAt: "2026-01-01T10:00:00.000Z", transcript: "test" },
  { id: "e2", createdAt: "2026-01-02T10:00:00.000Z", transcript: "test2" },
];

const funnels = computeBehaviorFunnels(events, entries);
assert.ok(funnels.some((f) => f.id === "first_to_second_reflection"));

const timing = computeReturnTiming(events, entries);
assert.ok(timing.length >= 2);

const segments = computeUserReturnSegments(events, entries);
assert.ok(segments.length >= 1);

const surfaces = computeSurfaceEffectiveness(events);
assert.ok(surfaces.some((s) => s.id === "homepage_callback"));

const copy = computeCopyEffectiveness(events);
assert.ok(copy.length >= 1);

const pressure = computeProductPressureWarnings(events, entries);
assert.ok(Array.isArray(pressure));

const insights = buildBehaviorInsightSummary({
  funnels,
  surfaces,
  copyRows: copy,
  ignoredSurfaces: [],
  strongestSurfaces: [],
  weakCopy: [],
  userSegments: segments,
  productPressure: pressure,
});
assert.ok(insights.length >= 1);
assert.ok(!insights[0].text.toLowerCase().includes("ai-powered"));

console.log("All behavior truth tests passed.");
