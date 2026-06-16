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
  "types/continuity-reinforcement.ts",
  "lib/archive/continuity-reinforcement.ts",
  "lib/archive/continuity-reinforcement-copy.ts",
  "components/archive/ContinuityStrip.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const copy = fs.readFileSync(
  path.join(ROOT, "lib/archive/continuity-reinforcement-copy.ts"),
  "utf8",
);
for (const example of [
  "This theory first appeared 37 days ago.",
  "This now appears in work and relationships.",
  "This theory has gained 12% confidence since last month.",
  "This has appeared in 4 separate reflections.",
  "Your archive is still testing this theory.",
]) {
  if (!copy.includes(example)) fail(`copy missing example: ${example}`);
}

const strip = fs.readFileSync(
  path.join(ROOT, "components/archive/ContinuityStrip.tsx"),
  "utf8",
);
if (!strip.includes('data-testid="continuity-strip"')) fail("strip test id missing");
if (!strip.includes("buildContinuityStripMessage")) fail("strip must build message");

const engine = fs.readFileSync(path.join(ROOT, "lib/archive/continuity-reinforcement.ts"), "utf8");
for (const kind of [
  "theory_first_appeared",
  "cross_life_areas",
  "confidence_change",
  "reflection_count",
  "still_testing",
  "archive_connecting",
]) {
  if (!engine.includes(kind)) fail(`engine missing kind ${kind}`);
}

const surfaces = [
  { file: "app/discover/page.tsx", prop: 'surface="discover"' },
  { file: "app/blind-spots/page.tsx", prop: 'surface="blind_spots"' },
  { file: "app/theories/page.tsx", prop: 'surface="theories"' },
  { file: "app/memory/page.tsx", prop: 'surface="memory"' },
  { file: "app/updates/page.tsx", prop: 'surface="updates"' },
];

for (const { file, prop } of surfaces) {
  const src = fs.readFileSync(path.join(ROOT, file), "utf8");
  if (!src.includes("ContinuityStrip")) fail(`${file} must render ContinuityStrip`);
  if (!src.includes(prop)) fail(`${file} must use ${prop}`);
}

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:continuity-reinforcement")) {
  fail("package.json missing validate:continuity-reinforcement");
}

const ls = new Map();
globalThis.window = { location: { pathname: "/validate-continuity-reinforcement" } };
globalThis.localStorage = {
  getItem: (k) => ls.get(String(k)) ?? null,
  setItem: (k, v) => ls.set(String(k), String(v)),
  removeItem: (k) => ls.delete(String(k)),
};

const { clearTheorySnapshotsForEval, upsertTheorySnapshots } = await import(
  "../lib/theories/theory-snapshots.ts"
);
const {
  buildContinuityStripMessage,
  CONTINUITY_REINFORCEMENT_SURFACES,
} = await import("../lib/archive/continuity-reinforcement.ts");

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
      recurringThemes: ["work", "relationships"],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
      concreteObservation: transcript.slice(0, 80),
      repeatedSignal: "partner and manager",
    },
  };
}

const old = entry(
  "cr-1",
  "My manager criticized my work and I felt like a failure at the office.",
  "2025-12-01T10:00:00.000Z",
);
const partner = entry(
  "cr-2",
  "My partner said I shut down again after conflict at home.",
  "2026-01-05T10:00:00.000Z",
);
const recent = entry(
  "cr-3",
  "Same failure feeling with my manager and partner both pushing me.",
  "2026-02-01T10:00:00.000Z",
);

for (const surface of CONTINUITY_REINFORCEMENT_SURFACES) {
  const msg = buildContinuityStripMessage([old, partner, recent], surface);
  assert.ok(msg.text.length > 10, `empty message for ${surface}`);
  assert.ok(msg.kind.length > 0, `missing kind for ${surface}`);
}

upsertTheorySnapshots([
  { theoryId: "placeholder", confidence: 40, contradictingCount: 0 },
]);
const withSnapshot = buildContinuityStripMessage([old, partner, recent], "discover");
assert.ok(withSnapshot.text.length > 0);

if (failures.length > 0) {
  console.error("validate-continuity-reinforcement failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-continuity-reinforcement ok", {
  surfaces: CONTINUITY_REINFORCEMENT_SURFACES.length,
  sample: withSnapshot.kind,
});
