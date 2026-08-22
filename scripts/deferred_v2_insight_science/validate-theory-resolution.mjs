#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
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

function entry(id, day, transcript) {
  const date = new Date(`2026-02-${String(day).padStart(2, "0")}T12:00:00.000Z`);
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
    },
    durationSeconds: 40,
  };
}

const base = [
  entry("e1", 1, "I keep saying I will start Monday but I never do."),
  entry("e2", 5, "I want to change but I keep doing the same thing at work."),
  entry("e3", 10, "I keep avoiding the conversation with my manager."),
  entry("e4", 15, "Maybe I will eventually tell them — I don't know."),
  entry("e5", 20, "I keep circling the same worry about money and work."),
  entry("e6", 25, "I should have spoken up but I keep waiting to quit."),
];

const {
  buildTheoryTrackerReport,
  buildTheoriesForEval,
} = await import("../../packages/shared/lib/theories/theory-generation.ts");
const { clearTheorySnapshotsForEval, upsertTheorySnapshots } = await import(
  "../../packages/shared/lib/theories/theory-snapshots.ts"
);
const { THEORY_RESOLUTION_COPY, resolveTheoryStatus } = await import(
  "../../packages/shared/lib/theories/theory-resolution.ts"
);
const { buildTheoryResolutionFeed } = await import(
  "../../packages/shared/lib/discover/theory-resolution-feed.ts"
);
const { buildTheoryDiscoveryReport } = await import(
  "../../packages/shared/lib/theories/theory-discovery-report.ts"
);
const { DISCOVER_PAGE } = await import("../../packages/shared/lib/discover/discover-copy.ts");
const { FORBIDDEN_THEORY_OUTPUT } = await import("../../packages/shared/lib/theories/theory-copy.ts");

clearTheorySnapshotsForEval();

const VALID_STATUS = new Set([
  "active",
  "strengthening",
  "weakening",
  "resolved",
  "retired",
]);

assert.equal(THEORY_RESOLUTION_COPY.softening, "This may be softening");
assert.equal(
  THEORY_RESOLUTION_COPY.mayNoLongerFit,
  "This theory may no longer fit",
);
assert.equal(
  THEORY_RESOLUTION_COPY.behaviorChanging,
  "Your recent reflections suggest this pattern may be changing",
);

for (const line of Object.values(THEORY_RESOLUTION_COPY)) {
  assert.ok(!FORBIDDEN_THEORY_OUTPUT.test(line), `forbidden copy: ${line}`);
}

const initial = buildTheoriesForEval(base);
assert.ok(initial.length >= 1);

for (const t of initial) {
  assert.ok(VALID_STATUS.has(t.status), `invalid status: ${t.status}`);
}

const target = initial[0];
upsertTheorySnapshots([
  {
    theoryId: target.id,
    confidence: Math.min(100, target.confidence + 18),
    contradictingCount: 0,
  },
]);

const shifted = [
  ...base,
  entry("c1", 28, "I finally had the talk with my manager and felt relieved."),
  entry("c2", 28, "I stopped avoiding and took action on the project."),
];
const afterShift = buildTheoryTrackerReport(shifted);
const lifecycle = afterShift.all.find((t) => t.id === target.id) ?? afterShift.all[0];

assert.ok(
  ["weakening", "resolved", "retired", "active"].includes(lifecycle.status),
  `expected lifecycle shift, got ${lifecycle.status}`,
);

const resolvedResult = resolveTheoryStatus({
  confidence: 44,
  previousConfidence: 58,
  confidenceDelta: -14,
  isFirstSnapshot: false,
  createdAt: "2025-12-01T00:00:00.000Z",
  supportingCount: 5,
  contradictingCount: 1,
  baselineContradictingCount: 0,
});
assert.equal(resolvedResult.status, "resolved");
assert.ok(resolvedResult.resolutionNote?.includes("no longer fit"));

const retiredResult = resolveTheoryStatus({
  confidence: 26,
  previousConfidence: 55,
  confidenceDelta: -29,
  isFirstSnapshot: false,
  createdAt: "2025-12-01T00:00:00.000Z",
  supportingCount: 2,
  contradictingCount: 4,
});
assert.equal(retiredResult.status, "retired");

const resolutionFeed = buildTheoryResolutionFeed(shifted);
assert.ok(typeof resolutionFeed.total === "number");
assert.ok(resolutionFeed.generatedAt.length > 0);

const discovery = buildTheoryDiscoveryReport(shifted);
assert.ok(typeof discovery.resolvedCount === "number");
assert.ok(typeof discovery.retiredCount === "number");
assert.equal(
  discovery.resolvedCount + discovery.retiredCount,
  resolutionFeed.total,
);

const report = buildTheoryTrackerReport(shifted);
assert.equal(
  report.active.length +
    report.strengthening.length +
    report.weakening.length +
    report.resolved.length +
    report.retired.length,
  report.all.length,
);

assert.ok(DISCOVER_PAGE.resolutionSectionTitle.length > 0);
assert.ok(DISCOVER_PAGE.resolutionSectionLead.length > 0);

const required = [
  "packages/shared/lib/theories/theory-resolution.ts",
  "packages/shared/lib/discover/theory-resolution-feed.ts",
  "apps/web/components/discover/TheoryResolutionSection.tsx",
  "apps/web/components/discover/TheoryChangeFeed.tsx",
  "apps/web/components/internal/TheoryDiscoveryPanel.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

const feedSrc = fs.readFileSync(
  path.join(ROOT, "apps/web/components/discover/TheoryChangeFeed.tsx"),
  "utf8",
);
if (!feedSrc.includes("TheoryResolutionSection")) {
  failures.push("TheoryChangeFeed must render TheoryResolutionSection");
}

const panelSrc = fs.readFileSync(
  path.join(ROOT, "apps/web/components/internal/TheoryDiscoveryPanel.tsx"),
  "utf8",
);
if (!panelSrc.includes("resolvedCount") || !panelSrc.includes("retiredCount")) {
  failures.push("TheoryDiscoveryPanel must show resolved/retired counts");
}

if (failures.length > 0) {
  console.error("validate-theory-resolution failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-theory-resolution ok");
