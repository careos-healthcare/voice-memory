import { buildMinimalReflectionFromTranscript, parseReflectionResponse } from "@/lib/analyze/parse-reflection-response";

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

function testParseValidReflection() {
  const raw = JSON.stringify({
    mood: "grateful",
    emotionalIntensity: 4,
    recurringThemes: ["thanks"],
    exactLanguagePattern: "Thank you.",
    concreteObservation: 'They said "Thank you."',
    repeatedSignal: "Nothing repeated clearly in this entry.",
  });
  const reflection = parseReflectionResponse(raw, "Thank you.");
  assert(reflection.exactLanguagePattern === "Thank you.", "exactLanguagePattern");
  assert(
    reflection.concreteObservation.includes("Thank you."),
    "concreteObservation",
  );
}

function testMinimalFallbackForInvalidModelJson() {
  const reflection = parseReflectionResponse("{not-json", "Thank you.");
  assert(reflection.concreteObservation.includes("Thank you."), "fallback observation");
}

function testMinimalReflectionBuilder() {
  const reflection = buildMinimalReflectionFromTranscript("Thank you.");
  assert(reflection.exactLanguagePattern === "Thank you.", "minimal quote");
}

export function runParseReflectionResponseTests(): void {
  testParseValidReflection();
  testMinimalFallbackForInvalidModelJson();
  testMinimalReflectionBuilder();
}

if (import.meta.url === `file://${process.argv[1]}`) {
  runParseReflectionResponseTests();
  console.log("parse-reflection-response tests passed");
}
