#!/usr/bin/env node
import assert from "node:assert/strict";

import { resetUnresolvedDetectionCache } from "../lib/open-loops/unresolved-cache.ts";
import { resetOpenLoopActivationCache } from "../lib/open-loops/open-loop-activation.ts";
import {
  getUnresolvedDetectionRunCount,
  resetOpenLoopPerformanceCounters,
} from "../lib/open-loops/open-loop-performance.ts";
import { readOpenLoopActivation, readUnresolvedThread } from "../lib/runtime/read-model.ts";
import { resetDeferredJobQueue } from "../lib/runtime/deferred-jobs.ts";
import { isReadOnlyPhase, runReadOnly } from "../lib/runtime/render-safe.ts";

const HAUNTED =
  "I am haunted by the past, the present and the future. I'm scared.";

resetUnresolvedDetectionCache();
resetOpenLoopActivationCache();
resetOpenLoopPerformanceCounters();
resetDeferredJobQueue();

readUnresolvedThread(HAUNTED);
readUnresolvedThread(HAUNTED);
assert.ok(getUnresolvedDetectionRunCount() <= 2);

const entry = {
  id: "runtime-entry",
  createdAt: "2026-05-01T12:00:00.000Z",
  transcript: HAUNTED,
  reflection: {
    mood: "",
    emotionalIntensity: 0,
    recurringThemes: [],
    hiddenConcern: "",
    positiveSignal: "",
    recommendation: "",
  },
  durationSeconds: 0,
};

let readPhaseDuringSelector = false;
runReadOnly("test", () => {
  readPhaseDuringSelector = isReadOnlyPhase();
  const activation = readOpenLoopActivation(entry);
  assert.equal(activation.showPrompt, true);
  assert.ok(activation.signal);
});
assert.equal(readPhaseDuringSelector, true);

console.log("All runtime boundary tests passed.");
