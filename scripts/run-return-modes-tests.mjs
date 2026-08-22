#!/usr/bin/env node
import assert from "node:assert/strict";

import {
  classifyResurfacingReturnMode,
  filterCallbacksByModeDiversity,
  getRecentResurfacingModes,
  isReturnModeBlocked,
  RESURFACING_RETURN_MODES,
} from "../packages/shared/lib/resurfacing/return-modes.ts";
const reflection = {
  mood: "anxious",
  emotionalIntensity: 4,
  recurringThemes: [],
  hiddenConcern: "",
  positiveSignal: "",
  recommendation: "",
};

const entries = [
  {
    id: "e1",
    createdAt: "2026-01-01T10:00:00.000Z",
    transcript: "I keep thinking about work and mum.",
    reflection: { ...reflection, emotionalIntensity: 3 },
    durationSeconds: 30,
  },
  {
    id: "e2",
    createdAt: "2026-01-20T10:00:00.000Z",
    transcript: "Work still feels heavier and more direct now.",
    reflection: { ...reflection, emotionalIntensity: 5 },
    durationSeconds: 40,
  },
];

const echoNote = {
  id: "echo-1",
  text: "You said something similar when you named this before.",
  category: "returned",
  confidence: 70,
  entryId: "e2",
  pastEntryId: "e1",
  pastQuote: "I keep thinking about work",
  currentQuote: "I keep thinking about work and mum",
};

const gapNote = {
  id: "gap-1",
  text: "You had not named this for a while.",
  category: "returned",
  confidence: 68,
  entryId: "e2",
  pastEntryId: "e1",
};

assert.equal(classifyResurfacingReturnMode(echoNote, entries), "exact_echo");
assert.equal(classifyResurfacingReturnMode(gapNote, entries), "silence_gap");
assert.equal(RESURFACING_RETURN_MODES.length, 5);

const diverse = filterCallbacksByModeDiversity(
  [echoNote, gapNote],
  entries,
  ["exact_echo", "contradiction", "silence_gap", "escalation", "recurrence_observation"],
);
assert.ok(diverse.length >= 1);

assert.equal(isReturnModeBlocked("exact_echo", ["exact_echo"]), true);
assert.equal(getRecentResurfacingModes().length, 0);

console.log("All return-modes tests passed.");
