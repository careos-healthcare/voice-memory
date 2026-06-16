#!/usr/bin/env node
/**
 * Personal Hypothesis Tracking — evidence building, confidence movement, discover reframe.
 */
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

function fail(msg) {
  failures.push(msg);
}

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

function mustExist(rel) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const CERTAINTY_RE =
  /\b(certainly|definitely|proven|guaranteed|will always cause|without doubt|confirmed diagnosis)\b/i;

const requiredFiles = [
  "types/personal-theory.ts",
  "lib/theories/personal-theory-status.ts",
  "lib/theories/personal-theory-map.ts",
  "lib/theories/theory-confidence-movement.ts",
  "lib/theories/personal-theory-copy.ts",
  "lib/metrics/theory-curiosity.ts",
  "components/theories/EvidenceBuildingCard.tsx",
  "components/theories/TheoryConfidenceMovement.tsx",
  "components/theories/TheoryCuriosityPrompt.tsx",
  "components/internal/TheoryCuriosityPanel.tsx",
];

for (const f of requiredFiles) mustExist(f);

const discover = read("lib/discover/discover-copy.ts");
const personalCopy = read("lib/theories/personal-theory-copy.ts");
if (!discover.includes("PERSONAL_HYPOTHESIS_DISCOVER")) {
  fail("discover must use PERSONAL_HYPOTHESIS_DISCOVER");
}
if (!personalCopy.includes("What your archive currently believes")) {
  fail("discover headline must be reframed");
}
if (!personalCopy.includes("strengthen, weaken, or disappear")) {
  fail("discover subheadline missing");
}

for (const phrase of [
  "What your archive currently believes",
  "You are building evidence",
  "Theory under review",
]) {
  if (!personalCopy.includes(phrase)) {
    const status = read("lib/theories/personal-theory-status.ts");
    if (phrase === "Theory under review" && status.includes(phrase)) continue;
    if (!read("components/theories/EvidenceBuildingCard.tsx").includes(phrase.split(" ")[0])) {
      fail(`missing copy: ${phrase}`);
    }
  }
}

const movement = read("lib/theories/theory-confidence-movement.ts");
if (!movement.includes("+") || !movement.includes("confidence")) {
  fail("confidence movement formatting missing");
}
if (!movement.includes("contradicted")) {
  fail("contradiction movement explanation missing");
}

const curiosity = read("lib/metrics/theory-curiosity.ts");
if (!curiosity.includes("voicememory_theory_curiosity")) {
  fail("theory curiosity storage key missing");
}
if (!curiosity.includes("theory_curiosity_open")) {
  fail("theory_curiosity_open event missing");
}
if (!curiosity.includes("curious whether it had changed")) {
  fail("theory curiosity question missing");
}

const panel = read("components/internal/TheoryCuriosityPanel.tsx");
if (!panel.includes("Theory Curiosity Rate")) {
  fail("internal Theory Curiosity Rate panel missing");
}

const evidenceCard = read("components/theories/EvidenceBuildingCard.tsx");
if (!evidenceCard.includes("evidence-building-card")) {
  fail("EvidenceBuildingCard test id missing");
}
if (!evidenceCard.includes("EVIDENCE_BUILDING_CARD_COPY")) {
  fail("EvidenceBuildingCard must use evidence building copy");
}

// User-facing surfaces wired
for (const [file, needle] of [
  ["app/discover/page.tsx", "EvidenceBuildingCard"],
  ["app/blind-spots/page.tsx", "EvidenceBuildingCard"],
  ["app/memory/page.tsx", "EvidenceBuildingCard"],
  ["components/Recorder.tsx", "EvidenceBuildingCard"],
  ["components/theories/TheoryCard.tsx", "TheoryConfidenceMovement"],
  ["components/blind-spots/BlindSpotReview.tsx", "TheoryConfidenceMovement"],
]) {
  const text = read(file);
  if (!text.includes(needle)) fail(`${file} must use ${needle}`);
}

// Scan user-facing copy files for certainty language
const scanPaths = [
  "lib/theories/personal-theory-copy.ts",
  "lib/discover/discover-copy.ts",
  "components/theories/EvidenceBuildingCard.tsx",
  "lib/metrics/theory-curiosity.ts",
];

for (const rel of scanPaths) {
  const text = read(rel);
  if (CERTAINTY_RE.test(text)) fail(`certainty language in ${rel}`);
}

// Runtime checks
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

const {
  EVIDENCE_BUILDING_REFLECTION_LABELS,
  evidenceBuildingLabelForCount,
} = await import("../lib/theories/personal-theory-status.ts");
const { formatConfidenceMovement, assertNoCertaintyLanguage } = await import(
  "../lib/theories/theory-confidence-movement.ts"
);
const {
  saveTheoryCuriosityAnswer,
  buildTheoryCuriosityReport,
  clearTheoryCuriosityForEval,
  THEORY_CURIOSITY_STORAGE_KEY,
} = await import("../lib/metrics/theory-curiosity.ts");
const { theoryToPersonalTheory } = await import("../lib/theories/personal-theory-map.ts");

assert.equal(EVIDENCE_BUILDING_REFLECTION_LABELS[2].statusLine, "Possible pattern");
assert.equal(EVIDENCE_BUILDING_REFLECTION_LABELS[3].statusLine, "Evidence growing");
assert.equal(EVIDENCE_BUILDING_REFLECTION_LABELS[4].statusLine, "Theory under review");
assert.equal(
  EVIDENCE_BUILDING_REFLECTION_LABELS[5].statusLine,
  "First working theory unlocked",
);
assert.equal(evidenceBuildingLabelForCount(2), "Possible pattern");

const move = formatConfidenceMovement({
  currentConfidence: 74,
  previousConfidence: 63,
  delta: 11,
  lifeAreaHint: "work",
});
assert.equal(move.currentConfidence, 74);
assert.ok(move.deltaLabel.includes("+11"));
assert.ok(move.explanation.includes("work"));
assertNoCertaintyLanguage(move.explanation);

clearTheoryCuriosityForEval();
saveTheoryCuriosityAnswer("yes");
saveTheoryCuriosityAnswer("maybe");
const report = buildTheoryCuriosityReport();
assert.equal(report.totalResponses, 2);
assert.equal(report.theoryCuriosityRate, 100);
assert.ok(storage.has(THEORY_CURIOSITY_STORAGE_KEY));

const personal = theoryToPersonalTheory({
  id: "t1",
  statement: "Your recorded history may suggest: you keep circling the same worry. This is a working theory — it may be wrong.",
  confidence: 55,
  previousConfidence: 44,
  confidenceDelta: 11,
  supportingEvidenceCount: 3,
  contradictingEvidenceCount: 1,
  createdAt: "2026-01-01T00:00:00.000Z",
  updatedAt: "2026-01-02T00:00:00.000Z",
  status: "active",
  supportingEvidence: [],
  contradictingEvidence: [],
  whatChanged: [],
  source: "pattern",
});

assert.equal(personal.status, "under_review");
assert.equal(personal.evidenceCount, 3);
assert.ok(personal.hypothesis.includes("working theory"));

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts?.["validate:personal-theory-tracking"]) {
  fail("package.json missing validate:personal-theory-tracking script");
}

if (failures.length) {
  console.error("validate-personal-theory-tracking failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-personal-theory-tracking ok");
