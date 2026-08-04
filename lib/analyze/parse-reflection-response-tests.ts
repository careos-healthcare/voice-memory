import { buildMinimalReflectionFromTranscript, parseReflectionResponse } from "@/lib/analyze/parse-reflection-response";

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

function validConclusion(transcript: string, statement: string) {
  const quote = transcript;
  return {
    id: "model-conclusion",
    statement,
    confidencePercent: 70,
    uncertaintyNote: "One entry may not establish a broader pattern.",
    evidence: [
      {
        entryId: "current-entry",
        quote,
        startUtf16: 0,
        endUtf16: quote.length,
        role: "support",
      },
    ],
    alternatives: [
      {
        statement: "This wording may describe only this moment.",
        reason: "A single transcript can support more than one narrow reading.",
      },
    ],
    provenance: {
      generatedBy: "model",
      generatedAt: "2026-07-26T09:00:00.000Z",
      model: "gpt-4o-mini",
      promptVersion: "analyze-explainable-v2",
    },
  };
}

function testParseValidReflection() {
  const transcript = "Thank you.";
  const raw = JSON.stringify({
    mood: "grateful",
    emotionalIntensity: 4,
    recurringThemes: ["thanks"],
    exactLanguagePattern: "UNVERIFIED FLAT QUOTE",
    concreteObservation: "UNVERIFIED FLAT OBSERVATION",
    repeatedSignal: "UNVERIFIED FLAT REPEAT",
    tensionOrContradiction: "UNVERIFIED FLAT TENSION",
    avoidedOrVagueArea: "UNVERIFIED FLAT AVOIDANCE",
    nextSmallAction: "UNVERIFIED FLAT ACTION",
    explainableConclusion: validConclusion(
      transcript,
      'Your words include "Thank you."',
    ),
  });
  const reflection = parseReflectionResponse(raw, transcript);
  assert(reflection.exactLanguagePattern === "Thank you.", "exactLanguagePattern");
  assert(
    reflection.concreteObservation === 'Your words include "Thank you."',
    "observation must derive from validated conclusion",
  );
  assert(
    !(reflection.repeatedSignal ?? "").includes("UNVERIFIED"),
    "repeat must be deterministic",
  );
  assert(!reflection.tensionOrContradiction, "unsupported tension must be blank");
  assert(!reflection.avoidedOrVagueArea, "unsupported avoidance must be blank");
  assert(!reflection.nextSmallAction, "unsupported action must be blank");
}

function testMinimalFallbackForInvalidModelJson() {
  const reflection = parseReflectionResponse("{not-json", "Thank you.");
  const observation = reflection.concreteObservation;
  assert(
    observation != null && observation.includes("Thank you"),
    "fallback observation",
  );
}

function testMinimalReflectionBuilder() {
  const reflection = buildMinimalReflectionFromTranscript("Thank you.");
  assert(reflection.exactLanguagePattern === "Thank you", "minimal quote");
  assert(
    reflection.explainableConclusion?.evidence[0]?.quote === "Thank you.",
    "fallback exact citation",
  );
}

function testMicroHabitFallback() {
  const reflection = buildMinimalReflectionFromTranscript(
    "When my manager asks late, I say yes before checking my calendar, then I lose my planning hour.",
  );
  assert(
    (reflection.concreteObservation ?? "").includes("When my manager asks late, you say yes"),
    "micro-habit observation",
  );
  assert(
    (reflection.concreteObservation ?? "").includes("; then you lose your planning hour"),
    "micro-habit should preserve ordered immediate cost",
  );
  assert(
    !(reflection.concreteObservation ?? "").includes("entire transcript"),
    "fallback must stay bounded",
  );
}

function testInternalPhraseRepetition() {
  const reflection = buildMinimalReflectionFromTranscript(
    "Maybe I can fit it. Maybe I can fit it after lunch.",
  );
  assert(reflection.exactLanguagePattern === "maybe", "repeated hedge");
  assert(
    (reflection.repeatedSignal ?? "").includes("inside this entry"),
    "entry-local repetition label",
  );
}

function testThinTranscriptHonesty() {
  const reflection = buildMinimalReflectionFromTranscript("");
  assert(
    (reflection.concreteObservation ?? "").includes("not enough spoken detail"),
    "thin input honesty",
  );
  assert(reflection.explainableConclusion === undefined, "thin input omits conclusion");
}

function testGenericModelOutputFallsBackToSpecificTranscript() {
  const raw = JSON.stringify({
    mood: "uncertain",
    emotionalIntensity: 4,
    recurringThemes: ["work"],
    exactLanguagePattern: "Entry language",
    concreteObservation: "You mentioned work.",
    repeatedSignal: "Nothing repeated clearly in this entry.",
    explainableConclusion: validConclusion(
      "Before the deadline arrives, I reopen the same draft three times.",
      "You mentioned work and this seems important.",
    ),
  });
  const reflection = parseReflectionResponse(
    raw,
    "Before the deadline arrives, I reopen the same draft three times.",
  );
  assert(
    (reflection.concreteObservation ?? "").includes("Before the deadline arrives"),
    "generic model output should use transcript fallback",
  );
}

function testInvalidConclusionReturnsEntireDeterministicFallback() {
  const transcript = "Before sending, I reopened the draft.";
  const expected = buildMinimalReflectionFromTranscript(transcript);
  const raw = JSON.stringify({
    mood: "model mood",
    emotionalIntensity: 10,
    recurringThemes: ["invented model theme"],
    exactLanguagePattern: "invented quote",
    concreteObservation: "invented observation",
    repeatedSignal: "invented repeat",
    tensionOrContradiction: "invented tension",
    avoidedOrVagueArea: "invented avoidance",
    nextSmallAction: "invented action",
    explainableConclusion: {
      ...validConclusion(transcript, "Invented conclusion"),
      evidence: [
        {
          entryId: "current-entry",
          quote: "wrong quote",
          startUtf16: 0,
          endUtf16: 11,
          role: "support",
        },
      ],
    },
  });
  const reflection = parseReflectionResponse(raw, transcript);
  assert(reflection.mood === expected.mood, "fallback mood");
  assert(
    JSON.stringify(reflection.recurringThemes) ===
      JSON.stringify(expected.recurringThemes),
    "fallback themes",
  );
  assert(
    reflection.concreteObservation === expected.concreteObservation,
    "fallback observation",
  );
  assert(
    reflection.explainableConclusion?.provenance.generatedBy === "deterministic",
    "fallback conclusion provenance",
  );
}

function testFallbackNeverInventsCrossRecordingRepeat() {
  const reflection = parseReflectionResponse(
    "{not-json",
    "I keep saying maybe, maybe I can finish.",
  );
  assert(
    !/across|prior|recordings/i.test(reflection.repeatedSignal ?? ""),
    "false recurrence",
  );
}

function testModelCrossRecordingClaimRequiresMatchingPriorEvidence() {
  const raw = JSON.stringify({
    mood: "focused",
    emotionalIntensity: 3,
    recurringThemes: ["work"],
    exactLanguagePattern: "reopened the draft",
    concreteObservation: 'You said "reopened the draft."',
    repeatedSignal: '"Reopened the draft" appeared in an earlier entry.',
  });
  const reflection = parseReflectionResponse(
    raw,
    "I reopened the draft before sending it.",
    [
      {
        id: "prior-1",
        createdAt: "2026-07-20T10:00:00.000Z",
        exactLanguagePattern: "I checked the calendar after lunch.",
      },
    ],
  );
  assert(
    !/earlier|prior|across/i.test(reflection.repeatedSignal ?? ""),
    "unmatched cross-recording claim",
  );
}

function testPositiveTwoRecordingRecurrence() {
  const transcript = "When a request lands, I say yes before checking.";
  const priorSnippet = "I say yes before checking my calendar.";
  const currentQuote = "say yes before checking";
  const priorQuote = "say yes before checking";
  const raw = JSON.stringify({
    mood: "rushed",
    emotionalIntensity: 5,
    recurringThemes: ["requests"],
    repeatedSignal:
      '"Say yes before checking" appears here and in the supplied prior entry.',
    explainableConclusion: {
      ...validConclusion(
        transcript,
        "Saying yes before checking recurs across recordings.",
      ),
      confidencePercent: 85,
      evidence: [
        {
          entryId: "current-entry",
          quote: currentQuote,
          startUtf16: transcript.indexOf(currentQuote),
          endUtf16: transcript.indexOf(currentQuote) + currentQuote.length,
          role: "support",
          sourceScope: "current_transcript",
        },
        {
          entryId: "prior-1",
          quote: priorQuote,
          startUtf16: priorSnippet.indexOf(priorQuote),
          endUtf16: priorSnippet.indexOf(priorQuote) + priorQuote.length,
          role: "support",
          sourceScope: "prior_exact_snippet",
          sourceField: "exactLanguagePattern",
        },
      ],
    },
  });
  const reflection = parseReflectionResponse(
    raw,
    transcript,
    [
      {
        id: "prior-1",
        createdAt: "2026-07-20T10:00:00.000Z",
        exactLanguagePattern: priorSnippet,
      },
    ],
  );
  assert(
    /supplied prior entry/i.test(reflection.repeatedSignal ?? ""),
    "strict two-recording recurrence should be preserved",
  );
  assert(
    reflection.explainableConclusion?.evidence.length === 2,
    "both exact citations should survive",
  );
}

export function runParseReflectionResponseTests(): void {
  testParseValidReflection();
  testMinimalFallbackForInvalidModelJson();
  testMinimalReflectionBuilder();
  testMicroHabitFallback();
  testInternalPhraseRepetition();
  testThinTranscriptHonesty();
  testGenericModelOutputFallsBackToSpecificTranscript();
  testInvalidConclusionReturnsEntireDeterministicFallback();
  testFallbackNeverInventsCrossRecordingRepeat();
  testModelCrossRecordingClaimRequiresMatchingPriorEvidence();
  testPositiveTwoRecordingRecurrence();
}

if (import.meta.url === `file://${process.argv[1]}`) {
  runParseReflectionResponseTests();
  console.log("parse-reflection-response tests passed");
}
