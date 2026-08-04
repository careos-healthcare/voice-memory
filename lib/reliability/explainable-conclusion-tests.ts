import assert from "node:assert/strict";

import { buildExactTranscriptCitation } from "@/lib/explainability/citations";
import { validateExplainableConclusion } from "@/lib/explainability/validate-explainable-conclusion";
import { validateConclusion } from "@/lib/archive-synthesis/archive-synthesis-common";
import type {
  ExplainableConclusion,
  ExplainableConclusionV4,
} from "@/types/explainability";

function conclusion(
  evidence: ExplainableConclusion["evidence"],
  confidencePercent = 70,
): ExplainableConclusion {
  const alternative = {
    statement: "The wording may be situational.",
    reason: "The cited transcript does not prove recurrence.",
  };
  return {
    id: "test-conclusion",
    statement: "The exact words support this narrow observation.",
    confidence: confidencePercent,
    confidencePercent,
    reasoning: ["The exact cited words support only this bounded observation."],
    alternativeExplanation: alternative,
    uncertainty: "This may apply only to the cited moment.",
    uncertaintyNote: "This may apply only to the cited moment.",
    evidence,
    alternatives: [alternative],
    provenance: {
      generatedBy: "deterministic",
      generatedAt: "2026-07-26T08:00:00.000Z",
      schemaVersion: 4,
    },
  };
}

export function runExplainableConclusionTests(): void {
  const emojiTranscript = "Start 🚀 now.";
  const emoji = buildExactTranscriptCitation("emoji", emojiTranscript, "🚀");
  assert.deepEqual(emoji, {
    sourceEntryId: "emoji",
    exactQuote: "🚀",
    confidenceScore: 1,
    entryId: "emoji",
    quote: "🚀",
    startUtf16: 6,
    endUtf16: 8,
    role: "support",
  });
  assert.equal(
    buildExactTranscriptCitation("emoji", emojiTranscript, "\ud83d"),
    null,
    "helper must not create a citation that splits an emoji",
  );
  assert.equal(
    validateExplainableConclusion(
      conclusion([emoji!]),
      new Map([["emoji", emojiTranscript]]),
    ).ok,
    true,
  );

  const splitSurrogate = { ...emoji!, startUtf16: 7 };
  assert.match(
    validateExplainableConclusion(
      conclusion([splitSurrogate]),
      new Map([["emoji", emojiTranscript]]),
    ).errors.join(" "),
    /surrogate pair/,
  );

  const repeatedTranscript = "maybe then maybe";
  assert.equal(
    buildExactTranscriptCitation("repeat", repeatedTranscript, "maybe", {
      occurrence: 1,
    })?.startUtf16,
    11,
  );

  const mismatch = { ...emoji!, startUtf16: 0, endUtf16: 2 };
  assert.match(
    validateExplainableConclusion(
      conclusion([mismatch]),
      new Map([["emoji", emojiTranscript]]),
    ).errors.join(" "),
    /exactly equal/,
  );

  assert.match(
    validateExplainableConclusion(
      conclusion([emoji!]),
      new Map([["different-entry", emojiTranscript]]),
    ).errors.join(" "),
    /unknown entryId/,
  );

  assert.match(
    validateExplainableConclusion(
      conclusion([emoji!], 71),
      new Map([["emoji", emojiTranscript]]),
    ).errors.join(" "),
    /exceeds evidence cap 70/,
  );

  const currentTranscript = "When asked, I say yes first.";
  const currentCitation = buildExactTranscriptCitation(
    "current",
    currentTranscript,
    "say yes",
    { sourceScope: "current_transcript" },
  )!;
  const priorSnippet = "🚀 I say yes before checking";
  const priorCitation = buildExactTranscriptCitation(
    "prior",
    priorSnippet,
    "🚀 I say yes",
    {
      sourceScope: "prior_exact_snippet",
      sourceField: "exactLanguagePattern",
    },
  )!;
  const recurrent = {
    ...conclusion([currentCitation, priorCitation], 85),
    statement: "Saying yes first recurs across recordings.",
  };
  assert.equal(
    validateExplainableConclusion(
      recurrent,
      new Map([["current", currentTranscript]]),
      "conclusion",
      {
        currentEntryId: "current",
        priorSnippetSources: new Map([
          ["prior", { exactLanguagePattern: priorSnippet }],
        ]),
        crossRecordingClaim: true,
      },
    ).ok,
    true,
    "current transcript and prior bounded snippet should validate",
  );
  assert.match(
    validateExplainableConclusion(
      {
        ...recurrent,
        evidence: [
          currentCitation,
          { ...priorCitation, startUtf16: 2, endUtf16: 13 },
        ],
      },
      new Map([["current", currentTranscript]]),
      "conclusion",
      {
        currentEntryId: "current",
        priorSnippetSources: new Map([
          ["prior", { exactLanguagePattern: priorSnippet }],
        ]),
        crossRecordingClaim: true,
      },
    ).errors.join(" "),
    /exactly equal|surrogate pair/,
    "prior snippet offsets must use exact UTF-16 boundaries",
  );
  assert.match(
    validateExplainableConclusion(
      recurrent,
      new Map([["current", currentTranscript]]),
      "conclusion",
      {
        currentEntryId: "current",
        priorSnippetSources: new Map([
          ["different-prior", { exactLanguagePattern: priorSnippet }],
        ]),
        crossRecordingClaim: true,
      },
    ).errors.join(" "),
    /unknown admitted prior exact snippet/,
    "unadmitted prior snippets must be rejected",
  );
  const unrelatedPrior = "I checked the calendar after lunch.";
  const unrelatedCitation = buildExactTranscriptCitation(
    "prior",
    unrelatedPrior,
    "checked the calendar",
    {
      sourceScope: "prior_exact_snippet",
      sourceField: "exactLanguagePattern",
    },
  )!;
  assert.match(
    validateExplainableConclusion(
      { ...recurrent, evidence: [currentCitation, unrelatedCitation] },
      new Map([["current", currentTranscript]]),
      "conclusion",
      {
        currentEntryId: "current",
        priorSnippetSources: new Map([
          ["prior", { exactLanguagePattern: unrelatedPrior }],
        ]),
        crossRecordingClaim: true,
      },
    ).errors.join(" "),
    /share exact recurring behavioral phrasing/,
    "unrelated but individually valid snippets must not prove recurrence",
  );

  const v4Alternative = {
    statement: "The wording may be situational.",
    reason: "The cited transcript does not prove recurrence.",
  };
  const v4: ExplainableConclusionV4 = {
    ...conclusion([emoji!]),
    confidence: 70,
    reasoning: [
      "The exact cited phrase is present in the canonical transcript.",
      "The evidence cap limits this conclusion to seventy percent.",
    ],
    alternativeExplanation: v4Alternative,
    uncertainty: "This may apply only to the cited moment.",
    alternatives: [v4Alternative],
    provenance: {
      generatedBy: "model",
      generatedAt: "2026-07-26T08:00:00.000Z",
      model: "test-model",
      schemaVersion: 4,
      promptVersion: "archive-explainable-v2",
    },
  };
  assert.deepEqual(
    validateConclusion(v4, new Map([["emoji", emojiTranscript]]), "v4"),
    [],
    "all five V4 pillars should validate",
  );
  assert.match(
    validateConclusion(
      { ...v4, reasoning: [] },
      new Map([["emoji", emojiTranscript]]),
      "v4",
    ).join(" "),
    /reasoning required/,
  );
}

if (import.meta.url === `file://${process.argv[1]}`) {
  runExplainableConclusionTests();
  console.log("explainable-conclusion tests passed");
}
