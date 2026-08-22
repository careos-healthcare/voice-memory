#!/usr/bin/env node
import {
  clearResurfacingFeedbackForEval,
  getSpecificityThresholdBoost,
  phraseKeyFromQuote,
  recordResurfacingFeedback,
  userFeedbackPenaltyForPhrase,
  isPhraseOnResurfacingCooldown,
} from "../packages/shared/lib/resurfacing/resurfacing-feedback.ts";
import { runCanonicalPipelineForContinuity } from "../packages/shared/lib/resurfacing/canonical-resurfacing-pipeline.ts";

const storage = new Map();
globalThis.localStorage = {
  getItem: (k) => storage.get(String(k)) ?? null,
  setItem: (k, v) => storage.set(String(k), String(v)),
  removeItem: (k) => storage.delete(String(k)),
  clear: () => storage.clear(),
  get length() {
    return storage.size;
  },
  key: (i) => [...storage.keys()][i] ?? null,
};

clearResurfacingFeedbackForEval();
const failures = [];

const quote = '"I cannot keep doing this alone"';
const key = phraseKeyFromQuote(quote);

recordResurfacingFeedback({ kind: "not_me", quote, surface: "callback" });
if (userFeedbackPenaltyForPhrase(key) < 35) {
  failures.push("not_me must apply >= 35 penalty");
}
const gated = runCanonicalPipelineForContinuity({
  quote,
  appearances: 4,
  gapDays: 3,
  threadType: "repeated_phrase",
});
if (gated.show) {
  failures.push("not_me must suppress future resurfacing");
}

clearResurfacingFeedbackForEval();
recordResurfacingFeedback({
  kind: "too_vague",
  quote: '"vague test phrase"',
  surface: "callback",
});
if (getSpecificityThresholdBoost() < 6) {
  failures.push("too_vague must raise specificity threshold");
}

clearResurfacingFeedbackForEval();
recordResurfacingFeedback({
  kind: "already_know",
  quote: '"already know phrase"',
  surface: "callback",
});
if (!isPhraseOnResurfacingCooldown(phraseKeyFromQuote('"already know phrase"'))) {
  failures.push("already_know must enter cooldown");
}

clearResurfacingFeedbackForEval();
recordResurfacingFeedback({
  kind: "that_fits",
  quote: '"that fits phrase"',
  surface: "callback",
});
if (userFeedbackPenaltyForPhrase(phraseKeyFromQuote('"that fits phrase"')) > 0) {
  failures.push("that_fits should not add rejection penalty");
}

if (failures.length) {
  console.error("validate-feedback-learning failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-feedback-learning ok");
