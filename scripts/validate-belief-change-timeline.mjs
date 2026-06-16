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
  "types/belief-timeline.ts",
  "lib/archive/belief-timeline.ts",
  "lib/archive/belief-timeline-storage.ts",
  "lib/archive/belief-timeline-copy.ts",
  "components/archive/BeliefChangeTimeline.tsx",
  "lib/founder-test/belief-reframing-validation.ts",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const card = fs.readFileSync(path.join(ROOT, "components/archive/ArchiveBeliefCard.tsx"), "utf8");
if (!card.includes("BeliefChangeTimeline")) fail("ArchiveBeliefCard must include timeline");

const events = fs.readFileSync(path.join(ROOT, "lib/metrics/archive-belief-events.ts"), "utf8");
if (!events.includes("belief_timeline_viewed")) fail("belief_timeline_viewed missing");

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:belief-change-timeline")) fail("package.json script missing");

const storage = new Map();
globalThis.window = { location: { pathname: "/validate-belief-change-timeline" } };
globalThis.localStorage = {
  getItem: (k) => storage.get(String(k)) ?? null,
  setItem: (k, v) => storage.set(String(k), String(v)),
  removeItem: (k) => storage.delete(String(k)),
};

const { clearBeliefTimelineForEval } = await import("../lib/archive/belief-timeline-storage.ts");
const { buildBeliefChangeTimeline } = await import("../lib/archive/belief-timeline.ts");
const { buildArchiveBeliefView } = await import("../lib/archive/archive-belief.ts");

clearBeliefTimelineForEval();

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
      repeatedSignal: "rejection",
    },
  };
}

const entries = [
  entry("bt-1", "Manager criticism at work feels like rejection.", "2026-03-01T10:00:00.000Z"),
  entry("bt-2", "Partner conflict at home — same rejection feeling.", "2026-04-05T10:00:00.000Z"),
  entry("bt-3", "Work feedback again — I am not enough.", "2026-05-10T10:00:00.000Z"),
  entry("bt-4", "Another fight at home about shutting down.", "2026-06-15T10:00:00.000Z"),
  entry("bt-5", "Office review stings the same way.", "2026-07-01T10:00:00.000Z"),
];

const belief = buildArchiveBeliefView(entries);
assert.ok(belief);

const timeline = buildBeliefChangeTimeline(entries, { theoryId: belief.theoryId });
assert.ok(timeline);
assert.ok(timeline.points.length >= 2);
assert.ok(timeline.points[0].periodLabel.length > 0);
assert.ok(timeline.points[0].confidence >= 0);

if (failures.length > 0) {
  console.error("validate-belief-change-timeline failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-belief-change-timeline ok", {
  points: timeline.points.length,
  latest: timeline.points[timeline.points.length - 1],
});
