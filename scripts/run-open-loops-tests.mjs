#!/usr/bin/env node
import assert from "node:assert/strict";

import {
  detectUnresolvedThread,
  hasUnresolvedThreadLanguage,
} from "../lib/open-loops/unresolved-signals.ts";
import { detectEmotionalShift } from "../lib/open-loops/emotional-shift.ts";
import { pickOpenLoopResurfacingLine } from "../lib/open-loops/open-loop-resurfacing-lines.ts";
import { hasLongAbsenceReturn } from "../lib/open-loops/open-loop-silence.ts";
assert.equal(hasUnresolvedThreadLanguage("I need to call them back tomorrow."), true);
assert.equal(
  hasUnresolvedThreadLanguage("Today was fine. Nothing unresolved."),
  false,
);

const signal = detectUnresolvedThread(
  "I keep avoiding the conversation. It sits there all week.",
);
assert.ok(signal);
assert.match(signal.anchorPhrases[0], /avoiding/i);

const waiting = detectUnresolvedThread("I'm waiting for them to reply before I decide.");
assert.ok(waiting);
assert.match(waiting.anchorPhrases[0], /waiting/i);
assert.equal(waiting.concernLabel, "Waiting");

const baseLoop = (overrides = {}) =>
  ({
    openLoopId: "loop-1",
    sourceEntryId: "entry-1",
    title: "Waiting",
    userNextStep: "Call when ready",
    status: "open",
    createdAt: "2026-01-01T10:00:00.000Z",
    updatedAt: "2026-02-01T10:00:00.000Z",
    lastMentionedAt: "2026-02-01T10:00:00.000Z",
    firstSeenAt: "2026-01-01T10:00:00.000Z",
    relatedEntryIds: ["entry-1", "entry-2"],
    anchorPhrases: ["I'm waiting for them", "still waiting"],
    concernLabel: "Waiting",
    recurrenceCount: 2,
    strongestAnchorPhrase: "I'm waiting for them",
    connectedMoments: [],
    mentionHistory: [
      "2026-01-01T10:00:00.000Z",
      "2026-02-15T10:00:00.000Z",
    ],
    ...overrides,
  });

const gapLine = pickOpenLoopResurfacingLine(baseLoop());
assert.ok(gapLine);
assert.match(gapLine, /after \d+ days/i);

const softenedLine = pickOpenLoopResurfacingLine(
  baseLoop({ status: "softened" }),
);
assert.equal(softenedLine, "You once marked this as softened.");

const absenceLoop = baseLoop({
  mentionHistory: [
    "2026-01-01T10:00:00.000Z",
    "2026-01-20T10:00:00.000Z",
  ],
});
assert.equal(hasLongAbsenceReturn(absenceLoop), true);

const shift = detectEmotionalShift(
  [
    {
      id: "a",
      createdAt: "2026-01-01T10:00:00.000Z",
      transcript: "I keep avoiding this call.",
      reflection: { mood: "anxious", emotionalIntensity: 7, recurringThemes: [], hiddenConcern: "", positiveSignal: "", recommendation: "" },
      durationSeconds: 30,
    },
    {
      id: "b",
      createdAt: "2026-01-20T10:00:00.000Z",
      transcript: "I came back to mention it again.",
      reflection: { mood: "anxious", emotionalIntensity: 7, recurringThemes: [], hiddenConcern: "", positiveSignal: "", recommendation: "" },
      durationSeconds: 30,
    },
  ],
  ["avoiding"],
);
assert.equal(shift.shift, "avoided_then_revisited");
assert.equal(shift.confidence, "high");

console.log("All open loop continuity tests passed.");
