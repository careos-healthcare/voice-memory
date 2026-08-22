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
    },
    durationSeconds: 40,
  };
}

const repeating = [
  entry("e1", 1, "I keep saying I will start Monday but I never do."),
  entry("e2", 5, "I want to change but I keep doing the same thing at work."),
  entry("e3", 10, "I keep avoiding the conversation with my manager."),
  entry("e4", 15, "Maybe I will eventually tell them — I don't know."),
  entry("e5", 20, "I keep circling the same worry about money and work."),
  entry("e6", 28, "I should have spoken up but I keep waiting to quit."),
];

const { buildTheoryChangeFeed } = await import("../../packages/shared/lib/discover/theory-change-feed.ts");
const {
  clearDiscoverVisitForEval,
  saveDiscoverVisitBaseline,
} = await import("../../packages/shared/lib/discover/discover-visit.ts");
const { buildTheoryTrackerReport } = await import("../../packages/shared/lib/theories/theory-generation.ts");
const { clearTheorySnapshotsForEval } = await import("../../packages/shared/lib/theories/theory-snapshots.ts");
const {
  clearTheoryEventsForEval,
  appendTheoryEventForEval,
  readAllTheoryEvents,
  THEORY_EVENTS,
} = await import("../../packages/shared/lib/theories/theory-events.ts");
const { buildSurfacePrimaryReport, countDiscoverOpens } = await import(
  "../../packages/shared/lib/discover/surface-primary-report.ts"
);
const { DISCOVER_PAGE } = await import("../../packages/shared/lib/discover/discover-copy.ts");

clearDiscoverVisitForEval();
clearTheorySnapshotsForEval();
clearTheoryEventsForEval();

const first = buildTheoryTrackerReport(repeating, { persistSnapshots: true });
const baselineTheories = first.all.map((t) => ({
  ...t,
  confidence: Math.max(0, t.confidence - 8),
}));
saveDiscoverVisitBaseline(baselineTheories, repeating);

const feed = buildTheoryChangeFeed(repeating);
assert.equal(feed.hasBaseline, true);
assert.ok(feed.totalChanges >= 1, "expected changes since baseline");
for (const item of [
  ...feed.strengthened,
  ...feed.weakened,
  ...feed.new,
  ...feed.resolved,
]) {
  assert.ok(item.shortReason.length > 0);
  assert.ok(item.theoryId.length > 0);
  assert.ok(["strengthened", "weakened", "new", "resolved"].includes(item.category));
}

appendTheoryEventForEval(THEORY_EVENTS.discoverOpened, { totalChanges: "2" });
appendTheoryEventForEval(THEORY_EVENTS.theoryChangeClicked, { theoryId: feed.strengthened[0]?.theoryId ?? "t1" });
assert.ok(readAllTheoryEvents().some((e) => e.name === "discover_opened"));

const surface = buildSurfacePrimaryReport();
assert.ok(typeof surface.theoryChangeOpenRate === "number");
assert.equal(surface.surfaces.length, 4);
assert.ok(surface.insightLines.length >= 4);
assert.ok(surface.surfaces.some((s) => s.surface === "blind_spot"));
assert.ok(surface.surfaces.some((s) => s.surface === "discover"));

assert.equal(DISCOVER_PAGE.heading, "What your archive currently believes");
assert.equal(countDiscoverOpens(), 1);

const required = [
  "apps/web/app/discover/page.tsx",
  "apps/web/components/discover/TheoryChangeFeed.tsx",
  "apps/web/components/discover/TheoryResolutionSection.tsx",
  "packages/shared/lib/discover/theory-resolution-feed.ts",
  "packages/shared/lib/discover/theory-change-feed.ts",
  "packages/shared/lib/discover/surface-primary-report.ts",
  "apps/web/components/internal/SurfacePrimaryPanel.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

const discoverPage = fs.readFileSync(path.join(ROOT, "apps/web/app/discover/page.tsx"), "utf8");
if (!discoverPage.includes("TheoryChangeFeed")) {
  failures.push("discover page must render TheoryChangeFeed");
}

if (failures.length > 0) {
  console.error("validate-theory-change-feed failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-theory-change-feed ok");
