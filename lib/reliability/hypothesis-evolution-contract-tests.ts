import assert from "node:assert/strict";

import { parseActiveHypotheses } from "@/lib/explainability/hypothesis-evolution-contract";
import { validateExplainableConclusion } from "@/lib/explainability/validate-explainable-conclusion";

export function runHypothesisEvolutionContractTests(): void {
  const quote = "Work pressure made me skip the walk.";
  const citation = {
    sourceEntryId: "entry-1",
    entryId: "entry-1",
    exactQuote: quote,
    quote,
    startUtf16: 0,
    endUtf16: quote.length,
    confidenceScore: 0.95,
    role: "support" as const,
  };
  const evolutionHistory = [
    {
      date: "2026-07-20T00:00:00.000Z",
      confidenceScore: 62,
      triggeringEvidence: citation,
      deltaReasoning: "Repeated evidence strengthened the working theory.",
    },
  ];
  const active = parseActiveHypotheses([
    {
      theoryId: "theory-work-walk",
      statement: "Work pressure may interrupt restorative habits.",
      evolutionHistory,
    },
  ]);
  assert.equal(active[0]?.theoryId, "theory-work-walk");

  const conclusion = {
    id: "conclusion-1",
    theoryId: "theory-work-walk",
    statement: "Work pressure may interrupt restorative habits.",
    confidence: 62,
    confidencePercent: 62,
    reasoning: ["Compared the new exact quote with the prior working theory."],
    uncertainty: "Only recorded moments are represented.",
    uncertaintyNote: "Only recorded moments are represented.",
    evidence: [citation],
    alternatives: [
      {
        statement: "The missed walk may have been unrelated to work.",
        reason: "One event cannot establish a stable pattern.",
      },
    ],
    alternativeExplanation: {
      statement: "The missed walk may have been unrelated to work.",
      reason: "One event cannot establish a stable pattern.",
    },
    provenance: {
      generatedBy: "model",
      generatedAt: "2026-07-20T00:00:00.000Z",
      schemaVersion: 4,
      promptVersion: "archive-explainable-v2",
    },
    evolutionHistory,
  };
  assert.equal(
    validateExplainableConclusion(
      conclusion,
      new Map([["entry-1", quote]]),
    ).ok,
    true,
  );
  assert.equal(
    validateExplainableConclusion(
      {
        ...conclusion,
        evolutionHistory: [
          { ...evolutionHistory[0], confidenceScore: 40 },
        ],
      },
      new Map([["entry-1", quote]]),
    ).ok,
    false,
  );
  assert.throws(
    () =>
      parseActiveHypotheses([
        {
          theoryId: "theory-resolved",
          statement: "Resolved theory",
          evolutionHistory: [
            { ...evolutionHistory[0], confidenceScore: 90 },
          ],
        },
      ]),
    /confidence must be below 85/,
  );
}
