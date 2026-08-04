import assert from "node:assert/strict";

import {
  parseDashboardSynthesisRequest,
  validateDashboardSynthesisResult,
} from "@/lib/dashboard-synthesis/dashboard-synthesis-contract";

export function runDashboardSynthesisContractTests(): void {
  const transcript = "I kept my morning walk and felt calmer afterward.";
  const request = parseDashboardSynthesisRequest({
    userId: "user-1",
    horizon: "this_month",
    localMetrics: { habitMentions: 4 },
    evidence: [
      {
        sourceEntryId: "entry-1",
        occurredAt: "2026-07-20T08:00:00.000Z",
        canonicalTranscript: transcript,
        audioTimestampMs: 3200,
      },
    ],
  });
  const quote = "morning walk";
  const start = transcript.indexOf(quote);
  const conclusion = {
    id: "habit-walk",
    statement: "Morning-walk mentions may support calmer days.",
    confidence: 70,
    confidencePercent: 70,
    evidence: [
      {
        sourceEntryId: "entry-1",
        exactQuote: quote,
        audioTimestampMs: 3200,
        confidenceScore: 0.95,
        entryId: "entry-1",
        quote,
        startUtf16: start,
        endUtf16: start + quote.length,
        role: "support",
      },
    ],
    reasoning: ["The cited entry links the routine with calmer language."],
    alternativeExplanation: {
      statement: "Another factor may explain the calmer day.",
      reason: "Only one recorded day is represented.",
    },
    alternatives: [
      {
        statement: "Another factor may explain the calmer day.",
        reason: "Only one recorded day is represented.",
      },
    ],
    uncertainty: "The evidence does not establish causation.",
    uncertaintyNote: "The evidence does not establish causation.",
    provenance: {
      generatedBy: "model",
      generatedAt: "2026-07-26T12:00:00.000Z",
      model: "test-model",
      schemaVersion: 4,
      promptVersion: "archive-explainable-v2",
    },
  };

  const valid = validateDashboardSynthesisResult(
    {
      horizon: "this_month",
      identity: null,
      goals: [],
      predictions: [conclusion],
    },
    request,
  );
  assert.equal(valid.ok, true, valid.errors.join("\n"));

  const invalid = validateDashboardSynthesisResult(
    {
      horizon: "this_month",
      identity: null,
      goals: [],
      predictions: [
        {
          ...conclusion,
          evidence: [{ ...conclusion.evidence[0], exactQuote: "invented" }],
        },
      ],
    },
    request,
  );
  assert.equal(invalid.ok, false);
  assert.match(invalid.errors.join("\n"), /exactQuote|quote/);

  assert.throws(
    () =>
      parseDashboardSynthesisRequest({
        userId: "user-1",
        horizon: "decade",
        localMetrics: {},
        evidence: [],
      }),
    /Invalid dashboard synthesis request/,
  );
}
