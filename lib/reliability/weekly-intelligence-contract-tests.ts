import assert from "node:assert/strict";

import {
  parseWeeklyIntelligenceRequest,
  validateWeeklyIntelligenceResult,
} from "@/lib/weekly-intelligence/weekly-intelligence-contract";

export function runWeeklyIntelligenceContractTests(): void {
  const baselineText = "I intend to begin the project after planning.";
  const currentText = "I completed the first project milestone today.";
  const request = parseWeeklyIntelligenceRequest({
    userId: "user-1",
    weekStart: "2026-07-20T00:00:00.000Z",
    weekEnd: "2026-07-27T00:00:00.000Z",
    baselineWeekCount: 3,
    localDeltas: [{ dimension: "action_intent_ratio", magnitude: 0.5 }],
    evidence: [
      {
        sourceEntryId: "baseline-1",
        week: "baseline",
        occurredAt: "2026-07-10T09:00:00.000Z",
        canonicalTranscript: baselineText,
      },
      {
        sourceEntryId: "current-1",
        week: "current",
        occurredAt: "2026-07-24T09:00:00.000Z",
        canonicalTranscript: currentText,
        audioTimestampMs: 4400,
      },
    ],
  });
  const conclusion = {
    id: "intent-action",
    statement: "Project language moved from intention toward reported execution.",
    confidence: 80,
    confidencePercent: 80,
    reasoning: [
      "The baseline quote states intent while the current quote reports completion.",
    ],
    uncertainty: "The recordings may omit unfinished work or other context.",
    uncertaintyNote: "The recordings may omit unfinished work or other context.",
    evidence: [
      citation("baseline-1", baselineText, "intend to begin"),
      citation("current-1", currentText, "completed the first"),
    ],
    alternativeExplanation: {
      statement: "The reported milestone may have been small.",
      reason: "The recording does not quantify the total project scope.",
    },
    alternatives: [
      {
        statement: "The reported milestone may have been small.",
        reason: "The recording does not quantify the total project scope.",
      },
    ],
    provenance: {
      generatedBy: "model",
      generatedAt: "2026-07-26T12:00:00.000Z",
      model: "test-model",
      schemaVersion: 4,
      promptVersion: "archive-explainable-v2",
    },
  };
  const result = {
    weekStart: request.weekStart,
    weekEnd: request.weekEnd,
    deltas: [
      {
        dimension: "action_intent_ratio",
        magnitude: 0.5,
        nodeIds: ["goal-project", "action-project"],
        conclusion,
      },
    ],
  };

  const valid = validateWeeklyIntelligenceResult(result, request);
  assert.equal(valid.ok, true, valid.errors.join("\n"));

  const oneSided = validateWeeklyIntelligenceResult(
    {
      ...result,
      deltas: [
        {
          ...result.deltas[0],
          conclusion: {
            ...conclusion,
            evidence: [conclusion.evidence[1]],
            confidence: 70,
            confidencePercent: 70,
          },
        },
      ],
    },
    request,
  );
  assert.equal(oneSided.ok, false);
  assert.match(oneSided.errors.join("\n"), /paired baseline and current/);

  const invented = validateWeeklyIntelligenceResult(
    {
      ...result,
      deltas: [
        {
          ...result.deltas[0],
          conclusion: {
            ...conclusion,
            evidence: [
              { ...conclusion.evidence[0], exactQuote: "invented quote" },
              conclusion.evidence[1],
            ],
          },
        },
      ],
    },
    request,
  );
  assert.equal(invented.ok, false);
  assert.match(invented.errors.join("\n"), /exactQuote/);
}

function citation(entryId: string, transcript: string, quote: string) {
  const start = transcript.indexOf(quote);
  return {
    sourceEntryId: entryId,
    exactQuote: quote,
    confidenceScore: 0.95,
    entryId,
    quote,
    startUtf16: start,
    endUtf16: start + quote.length,
    role: "support",
  };
}
