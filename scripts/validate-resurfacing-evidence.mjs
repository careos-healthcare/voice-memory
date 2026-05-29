#!/usr/bin/env node
import { runCanonicalPipelineForContinuity } from "../lib/resurfacing/canonical-resurfacing-pipeline.ts";
import { buildResurfacingEvidence, hasResurfacingEvidenceAnchors } from "../lib/resurfacing/resurfacing-evidence.ts";

const failures = [];

const noEvidence = runCanonicalPipelineForContinuity({
  quote: "stressed",
  appearances: 1,
});
if (noEvidence.show) {
  failures.push("generic low-evidence quote must not show");
}

const withEvidence = runCanonicalPipelineForContinuity({
  quote: '"I keep saying I will call her back tomorrow — same line again"',
  appearances: 4,
  gapDays: 5,
  threadType: "repeated_phrase",
});
if (!withEvidence.show) {
  failures.push("quote-backed recurrence should pass gate");
}
const whyLine = withEvidence.whySurfacedLines?.[0] ?? "";
if (!whyLine || whyLine.length < 12) {
  failures.push("why-surfaced line required when shown");
}

const evidence = buildResurfacingEvidence({
  quote: '"manager keeps moving the deadline"',
  appearances: 3,
  gapDays: 8,
});
if (!hasResurfacingEvidenceAnchors(evidence) && evidence.exactQuoteMatches.length === 0) {
  failures.push("evidence object must include anchors for quoted input");
}

const stale = runCanonicalPipelineForContinuity({
  quote: '"fine whatever"',
  appearances: 4,
  gapDays: 35,
});
if (stale.show) {
  failures.push("stale callback without reinforcement should suppress");
}

if (failures.length) {
  console.error("validate-resurfacing-evidence failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-resurfacing-evidence ok");
