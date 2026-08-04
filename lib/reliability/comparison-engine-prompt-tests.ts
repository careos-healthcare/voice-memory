import assert from "node:assert/strict";

import {
  COMPARISON_BANNED_PHRASE_PREFIXES,
  COMPARISON_CONFIDENCE_LABELS,
  COMPARISON_ENGINE_SYSTEM_PROMPT,
  COMPARISON_THIN_EVIDENCE_DEFAULT,
  allowsMissingComparisonEvidenceQuotes,
  comparisonOutputHasRequiredEvidenceQuotes,
  formatComparisonStructuredSummary,
  violatesComparisonBannedPhrase,
  type ComparisonEngineOutput,
} from "@/lib/comparison/comparison-engine-prompt";

function check(name: string, fn: () => void): void {
  try {
    fn();
    console.info(`ok ${name}`);
  } catch (error) {
    console.error(`fail ${name}`);
    throw error;
  }
}

check("system prompt bans identity framing phrases", () => {
  assert.match(COMPARISON_ENGINE_SYSTEM_PROMPT, /You always/);
  assert.match(COMPARISON_ENGINE_SYSTEM_PROMPT, /This means/);
  assert.match(COMPARISON_ENGINE_SYSTEM_PROMPT, /Your pattern is/);
  assert.match(COMPARISON_ENGINE_SYSTEM_PROMPT, /deep fear of/);
  assert.match(COMPARISON_ENGINE_SYSTEM_PROMPT, /Here is my diagnosis/);
});

check("system prompt requires markdown evidence quotes", () => {
  assert.match(COMPARISON_ENGINE_SYSTEM_PROMPT, /Evidence:/);
  assert.match(COMPARISON_ENGINE_SYSTEM_PROMPT, /- Past:/);
  assert.match(COMPARISON_ENGINE_SYSTEM_PROMPT, /- Present:/);
});

check("confidence labels are exact and complete", () => {
  assert.deepEqual(COMPARISON_CONFIDENCE_LABELS, [
    "Early signal",
    "Possible repeat",
    "Clear repeat",
    "Still current",
    "Fading",
    "Changed",
    "Softened",
    "Corrected",
    "Not enough evidence",
  ]);
});

check("structured summary includes evidence quotes", () => {
  const output: ComparisonEngineOutput = {
    confidenceLabel: "Possible repeat",
    whatAppearsRepeated: "Saying yes before checking capacity.",
    connectedMomentDayTime: "10 June 2026 · 9:15 AM",
    connectedEntryId: "entry_a",
    whatChanged: "It showed up around work again.",
    thinEvidencePhrase: COMPARISON_THIN_EVIDENCE_DEFAULT,
    pastQuote: "I said yes again before I checked my calendar.",
    presentQuote: "I said yes at work without thinking.",
  };
  const summary = formatComparisonStructuredSummary(output);
  assert.match(summary, /Label: Possible repeat/);
  assert.match(summary, /Connection: Saying yes before checking capacity./);
  assert.match(summary, /Connects to: 10 June 2026 · 9:15 AM/);
  assert.match(summary, /- Past: "I said yes again before I checked my calendar."/);
  assert.match(summary, /- Present: "I said yes at work without thinking."/);
  assert.match(summary, /What changed: It showed up around work again./);
  assert.match(summary, new RegExp(COMPARISON_THIN_EVIDENCE_DEFAULT));
  assert.equal(comparisonOutputHasRequiredEvidenceQuotes(output), true);
});

check("not enough evidence allows missing quotes", () => {
  const output: ComparisonEngineOutput = {
    confidenceLabel: "Not enough evidence",
    whatAppearsRepeated: "The moments may be unrelated.",
    connectedMomentDayTime: "10 June 2026 · 9:15 AM",
    pastQuote: "",
    presentQuote: "",
  };
  assert.equal(allowsMissingComparisonEvidenceQuotes(output.confidenceLabel), true);
  assert.equal(comparisonOutputHasRequiredEvidenceQuotes(output), true);
});

check("violatesComparisonBannedPhrase catches banned openings", () => {
  for (const prefix of COMPARISON_BANNED_PHRASE_PREFIXES) {
    assert.equal(violatesComparisonBannedPhrase(`${prefix} something`), true);
  }
  assert.equal(
    violatesComparisonBannedPhrase("Both moments may touch on saying yes."),
    false,
  );
});

console.info("comparison-engine-prompt-tests: all passed");
