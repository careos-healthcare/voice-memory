#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const required = [
  "lib/blind-spots/evidence-accuracy.ts",
  "lib/blind-spots/blind-spot-ranking.ts",
  "types/blind-spot.ts",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

const accuracySrc = fs.readFileSync(
  path.join(ROOT, "lib/blind-spots/evidence-accuracy.ts"),
  "utf8",
);
if (!accuracySrc.includes("passesSkepticEvidenceGate")) {
  failures.push("evidence-accuracy must define skeptic gate");
}
if (!accuracySrc.includes("deriveRootBeliefHypothesis")) {
  failures.push("evidence-accuracy must define rootBeliefHypothesis");
}

const reviewSrc = fs.readFileSync(
  path.join(ROOT, "lib/blind-spots/blind-spot-review.ts"),
  "utf8",
);
if (!reviewSrc.includes("rankBlindSpotCandidates")) {
  failures.push("blind-spot-review must use rankBlindSpotCandidates");
}

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:blind-spot-tests")) {
  failures.push("package.json must include validate:blind-spot-tests");
}

const { FORBIDDEN_ROOT_BELIEF, deriveRootBeliefHypothesis } = await import(
  "../lib/blind-spots/evidence-accuracy.ts"
);

const sample = deriveRootBeliefHypothesis(
  {
    id: "x",
    sourceKey: "x",
    type: "contradiction",
    title: "pulls",
    detail: "want and habit",
    evidence: [{ entryId: "e1", phrase: "conflict at work" }],
    entryIds: ["e1"],
    scores: { recurrenceCount: 5 },
    specificity: { isWeakOrGeneric: false, specificityScore: 80 },
  },
  ["conflict"],
);
assert.ok(sample && !FORBIDDEN_ROOT_BELIEF.test(sample));

const toxic = deriveRootBeliefHypothesis(
  {
    id: "y",
    sourceKey: "y",
    type: "repeated_phrase",
    title: "therapy disorder",
    detail: "clinical trauma patholog",
    evidence: [{ entryId: "e1", phrase: "diagnos disorder therapy" }],
    entryIds: ["e1"],
    scores: { recurrenceCount: 5 },
    specificity: { isWeakOrGeneric: false, specificityScore: 80 },
  },
  [],
);
if (toxic && FORBIDDEN_ROOT_BELIEF.test(toxic)) {
  failures.push("root belief sanitizer must strip forbidden copy");
}

if (failures.length > 0) {
  console.error("validate-uncomfortably-accurate failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-uncomfortably-accurate ok");
