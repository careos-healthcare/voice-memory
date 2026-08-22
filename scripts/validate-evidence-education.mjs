#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

function fail(msg) {
  failures.push(msg);
}

const required = [
  "packages/shared/lib/archive/evidence-education-copy.ts",
  "packages/shared/lib/archive/evidence-education.ts",
  "packages/shared/lib/metrics/evidence-education-events.ts",
  "apps/web/components/archive/WhyMoreEvidenceMatters.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const copy = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/archive/evidence-education-copy.ts"),
  "utf8",
);
for (const phrase of [
  "A single reflection can be misleading.",
  "Repeated evidence is harder to ignore.",
  "strengthen a theory",
  "weaken a theory",
  "contradict a theory",
  "reveal a new pattern",
  "ArchiveMe becomes more accurate when evidence accumulates.",
]) {
  if (!copy.includes(phrase)) fail(`copy missing: ${phrase}`);
}

const component = fs.readFileSync(
  path.join(ROOT, "apps/web/components/archive/WhyMoreEvidenceMatters.tsx"),
  "utf8",
);
if (!component.includes("trackWhyEvidenceMattersSeen")) {
  fail("component must track why_evidence_matters_seen");
}
if (!component.includes('data-testid="why-more-evidence-matters"')) {
  fail("component test id missing");
}

const events = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/metrics/evidence-education-events.ts"),
  "utf8",
);
if (!events.includes("why_evidence_matters_seen")) fail("metric name missing");

const engine = fs.readFileSync(path.join(ROOT, "packages/shared/lib/archive/evidence-education.ts"), "utf8");
for (const n of [3, 4, 5, 6, 7]) {
  if (!engine.includes(String(n))) fail(`engine must include reflection count ${n}`);
}

const surfaces = [
  "apps/web/components/Recorder.tsx",
  "apps/web/app/memory/page.tsx",
  "apps/web/app/discover/page.tsx",
  "apps/web/app/blind-spots/page.tsx",
  "apps/web/app/theories/page.tsx",
  "apps/web/app/entry/[id]/page.tsx",
  "apps/web/app/updates/page.tsx",
];
for (const rel of surfaces) {
  const src = fs.readFileSync(path.join(ROOT, rel), "utf8");
  if (!src.includes("WhyMoreEvidenceMatters")) fail(`${rel} must render WhyMoreEvidenceMatters`);
}

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:evidence-education")) fail("package.json missing script");

const storage = new Map();
globalThis.window = { location: { pathname: "/validate-evidence-education" } };
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

const { clearTheorySnapshotsForEval, upsertTheorySnapshots } = await import(
  "../packages/shared/lib/theories/theory-snapshots.ts"
);
const {
  buildEvidenceEducationVisibility,
  isEvidenceEducationReflectionCount,
} = await import("../packages/shared/lib/archive/evidence-education.ts");
const {
  trackWhyEvidenceMattersSeen,
  countWhyEvidenceMattersSeen,
  WHY_EVIDENCE_MATTERS_SEEN,
} = await import("../packages/shared/lib/metrics/evidence-education-events.ts");
const { scanArchiveVoiceSource } = await import("../packages/shared/lib/archive/archive-voice.ts");

clearTheorySnapshotsForEval();

function entry(id, transcript, createdAt) {
  return {
    id,
    createdAt,
    transcript,
    durationSeconds: 45,
    reflection: {
      mood: "reflective",
      emotionalIntensity: 3,
      recurringThemes: ["work"],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
      concreteObservation: transcript.slice(0, 80),
      repeatedSignal: "failure language",
    },
  };
}

function makeEntries(count) {
  return Array.from({ length: count }, (_, i) =>
    entry(
      `ee-${i + 1}`,
      `I keep failing at work when feedback arrives — reflection ${i + 1}.`,
      new Date(`2026-01-${String(i + 1).padStart(2, "0")}T12:00:00.000Z`).toISOString(),
    ),
  );
}

assert.equal(isEvidenceEducationReflectionCount(6), true);
assert.equal(isEvidenceEducationReflectionCount(5), true);
assert.equal(isEvidenceEducationReflectionCount(2), false);
assert.equal(isEvidenceEducationReflectionCount(8), false);

const atSix = buildEvidenceEducationVisibility(makeEntries(6));
assert.equal(atSix.show, true);
assert.equal(atSix.trigger, "reflection_count");
assert.equal(atSix.reflectionCount, 6);

const atTwo = buildEvidenceEducationVisibility(makeEntries(2));
assert.equal(atTwo.show, false);

const atEight = buildEvidenceEducationVisibility(makeEntries(8));
assert.equal(atEight.show, false);

const sixEntries = makeEntries(6);
upsertTheorySnapshots([{ theoryId: "placeholder", confidence: 40 }]);
const withTheory = buildEvidenceEducationVisibility(sixEntries);
assert.equal(withTheory.show, true);

trackWhyEvidenceMattersSeen({ reflectionCount: 6, trigger: "reflection_count" });
assert.equal(countWhyEvidenceMattersSeen(), 1);
assert.equal(WHY_EVIDENCE_MATTERS_SEEN, "why_evidence_matters_seen");

const voiceHits = scanArchiveVoiceSource(copy, "evidence-education-copy.ts");
if (voiceHits.length > 0) {
  fail(`evidence education copy failed archive voice: ${voiceHits[0].match}`);
}

if (failures.length > 0) {
  console.error("validate-evidence-education failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-evidence-education ok", {
  atSix: atSix.trigger,
  seen: countWhyEvidenceMattersSeen(),
});
