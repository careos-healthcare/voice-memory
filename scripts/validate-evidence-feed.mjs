#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

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

function entry(id, day, transcript, reflection = {}) {
  const date = new Date(`2026-01-${String(day).padStart(2, "0")}T12:00:00.000Z`);
  return {
    id,
    createdAt: date.toISOString(),
    transcript,
    reflection: {
      mood: "tense",
      emotionalIntensity: 6,
      recurringThemes: ["work"],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
      ...reflection,
    },
    durationSeconds: 40,
  };
}

const baselineEntries = [
  entry("e1", 1, "I keep saying I will start Monday but I never do."),
  entry("e2", 5, "I want to change but I keep doing the same thing at work."),
  entry("e3", 10, "I keep avoiding the conversation with my manager."),
  entry("e4", 15, "Maybe I will eventually tell them — I don't know."),
  entry("e5", 20, "I keep circling the same worry about money and work."),
];

const expandedEntries = [
  ...baselineEntries,
  entry(
    "e6",
    28,
    "I should have spoken up but I keep waiting to quit. I keep avoiding conflict at work and putting off the decision.",
    { recurringThemes: ["work", "money"] },
  ),
];

const { buildEvidenceFeed } = await import("../packages/shared/lib/discover/evidence-feed.ts");
const { buildTheoryTrackerReport } = await import("../packages/shared/lib/theories/theory-generation.ts");
const {
  clearDiscoverVisitForEval,
  saveDiscoverVisitBaseline,
  readDiscoverBaseline,
} = await import("../packages/shared/lib/discover/discover-visit.ts");
const { clearTheorySnapshotsForEval } = await import("../packages/shared/lib/theories/theory-snapshots.ts");
const { theoryToEvidenceBaseline, buildDiscoverEvidenceContext } = await import(
  "../packages/shared/lib/discover/theory-evidence-snapshot.ts"
);
const { DISCOVER_PAGE } = await import("../packages/shared/lib/discover/discover-copy.ts");

clearDiscoverVisitForEval();
clearTheorySnapshotsForEval();

const firstReport = buildTheoryTrackerReport(baselineEntries, { persistSnapshots: true });
saveDiscoverVisitBaseline(firstReport.all, baselineEntries);

const baseline = readDiscoverBaseline();
assert.ok(baseline);
assert.equal(baseline.version, 2);
assert.ok(baseline.theories[0]?.supportingEntryIds?.length >= 0);

const feedNoChange = buildEvidenceFeed(baselineEntries);
assert.equal(feedNoChange.hasBaseline, true);

const feedWithNew = buildEvidenceFeed(expandedEntries);
assert.ok(feedWithNew.totalMovements >= 1, "expected evidence movement after new reflection");

const kinds = new Set(feedWithNew.movements.map((m) => m.kind));
assert.ok(
  kinds.has("new_supporting") ||
    kinds.has("confidence_movement") ||
    kinds.has("new_life_area") ||
    kinds.has("new_cost_evidence"),
  `expected movement kinds, got ${[...kinds].join(",")}`,
);

for (const m of feedWithNew.movements) {
  assert.ok(m.summary.length > 0);
  assert.ok(m.theoryId.length > 0);
}

assert.equal(
  DISCOVER_PAGE.evidenceEmpty,
  "No new evidence yet. Record again when something is on your mind.",
);

const context = buildDiscoverEvidenceContext(expandedEntries);
const snap = theoryToEvidenceBaseline(firstReport.all[0], expandedEntries, context);
assert.ok(Array.isArray(snap.lifeAreas));
assert.ok(Array.isArray(snap.costEvidenceLines));

const required = [
  "packages/shared/types/evidence-feed.ts",
  "packages/shared/lib/discover/evidence-feed.ts",
  "packages/shared/lib/discover/theory-evidence-snapshot.ts",
  "apps/web/components/discover/EvidenceFeedSection.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

const discoverUi = fs.readFileSync(
  path.join(ROOT, "apps/web/components/discover/TheoryChangeFeed.tsx"),
  "utf8",
);
if (!discoverUi.includes("EvidenceFeedSection")) {
  failures.push("TheoryChangeFeed must render EvidenceFeedSection");
}
if (!discoverUi.includes("buildEvidenceFeed")) {
  failures.push("TheoryChangeFeed must build evidence feed");
}

if (failures.length > 0) {
  console.error("validate-evidence-feed failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-evidence-feed ok");
