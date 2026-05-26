#!/usr/bin/env node
import assert from "node:assert/strict";

import {
  getCachedUnresolvedThread,
  resetUnresolvedDetectionCache,
} from "../lib/open-loops/unresolved-cache.ts";
import {
  getUnresolvedDetectionRunCount,
  resetOpenLoopPerformanceCounters,
} from "../lib/open-loops/open-loop-performance.ts";
import {
  resetOpenLoopActivationCache,
  resolveOpenLoopActivation,
} from "../lib/open-loops/open-loop-activation.ts";
import { resolveOpenLoopActivationSuppression } from "../lib/open-loops/open-loop-activation-audit.ts";

const HAUNTED =
  "I am haunted by the past, the present and the future. I'm scared.";

resetUnresolvedDetectionCache();
resetOpenLoopActivationCache();
resetOpenLoopPerformanceCounters();

getCachedUnresolvedThread(HAUNTED);
getCachedUnresolvedThread(HAUNTED);
getCachedUnresolvedThread(HAUNTED);

assert.ok(getUnresolvedDetectionRunCount() <= 2, `expected <=2 detection runs, got ${getUnresolvedDetectionRunCount()}`);

const entry = {
  id: "perf-entry-1",
  createdAt: "2026-05-01T12:00:00.000Z",
  transcript: HAUNTED,
  reflection: {
    mood: "anxious",
    emotionalIntensity: 6,
    recurringThemes: [],
    hiddenConcern: "",
    positiveSignal: "",
    recommendation: "",
  },
  durationSeconds: 30,
};

const activation = resolveOpenLoopActivation(entry);
assert.equal(activation.showPrompt, true);
assert.equal(
  resolveOpenLoopActivationSuppression(entry, { dismissed: false, hasLoop: false }),
  null,
);

resolveOpenLoopActivation(entry);
resolveOpenLoopActivation(entry);
assert.ok(activation.showPrompt, "prompt allowed on hydration path");

console.log("All open loop performance tests passed.");
