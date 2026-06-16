#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const storage = new Map();
const sessionStorage = new Map();

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

globalThis.sessionStorage = {
  getItem: (k) => sessionStorage.get(String(k)) ?? null,
  setItem: (k, v) => sessionStorage.set(String(k), String(v)),
  removeItem: (k) => sessionStorage.delete(String(k)),
  clear: () => sessionStorage.clear(),
  get length() {
    return sessionStorage.size;
  },
  key: (i) => [...sessionStorage.keys()][i] ?? null,
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

const repeating = [
  entry("e1", 1, "I keep saying I will start Monday but I never do."),
  entry("e2", 5, "I want to change but I keep doing the same thing at work."),
  entry("e3", 10, "I keep avoiding the conversation with my manager."),
  entry("e4", 15, "Maybe I will eventually tell them — I don't know."),
  entry("e5", 20, "I keep circling the same worry about money and work."),
  entry("e6", 28, "I should have spoken up but I keep waiting to quit."),
];

const {
  recordDiscoverVolatilitySample,
  buildTheoryVolatilityReport,
  classifyTheoryVolatilityRisk,
  clearTheoryVolatilityForEval,
  THEORY_VOLATILITY_RISK_LABELS,
  readTheoryVolatilityState,
} = await import("../lib/discover/theory-volatility.ts");
const { buildTheoryDiscoveryReport } = await import(
  "../lib/theories/theory-discovery-report.ts"
);
const { clearTheorySnapshotsForEval } = await import("../lib/theories/theory-snapshots.ts");
const { clearTheoryEventsForEval } = await import("../lib/theories/theory-events.ts");

clearTheoryVolatilityForEval();
clearTheorySnapshotsForEval();
clearTheoryEventsForEval();
sessionStorage.set("voicememory_app_session_count", "3");

assert.equal(THEORY_VOLATILITY_RISK_LABELS.healthy, "Healthy");
assert.equal(THEORY_VOLATILITY_RISK_LABELS.quiet, "Quiet");
assert.equal(THEORY_VOLATILITY_RISK_LABELS.stale, "Stale");
assert.equal(THEORY_VOLATILITY_RISK_LABELS.dead_feed_risk, "Dead feed risk");

assert.equal(
  classifyTheoryVolatilityRisk({
    daysSinceLastChange: 15,
    zeroMovementVisitRate: 80,
    staleZeroMovementSessions: 0,
    cumulativeMovementEvents: 1,
    discoverVisitCount: 5,
    lastVisitHadZeroMovement: true,
  }),
  "dead_feed_risk",
);

assert.equal(
  classifyTheoryVolatilityRisk({
    daysSinceLastChange: 11,
    zeroMovementVisitRate: 70,
    staleZeroMovementSessions: 0,
    cumulativeMovementEvents: 2,
    discoverVisitCount: 6,
    lastVisitHadZeroMovement: true,
  }),
  "stale",
);

assert.equal(
  classifyTheoryVolatilityRisk({
    daysSinceLastChange: 2,
    zeroMovementVisitRate: 20,
    staleZeroMovementSessions: 0,
    cumulativeMovementEvents: 8,
    discoverVisitCount: 6,
    lastVisitHadZeroMovement: false,
  }),
  "healthy",
);

recordDiscoverVolatilitySample({
  totalTheories: 3,
  strengthenedCount: 2,
  weakenedCount: 0,
  resolvedCount: 0,
  retiredCount: 0,
  theoryChangeCount: 2,
  evidenceMovementCount: 1,
  hasBaseline: true,
});

recordDiscoverVolatilitySample({
  totalTheories: 3,
  strengthenedCount: 0,
  weakenedCount: 0,
  resolvedCount: 0,
  retiredCount: 0,
  theoryChangeCount: 0,
  evidenceMovementCount: 0,
  hasBaseline: true,
});

const state = readTheoryVolatilityState();
assert.equal(state.discoverVisitCount, 2);
assert.equal(state.zeroMovementVisits, 1);
assert.ok(state.cumulativeStrengthened >= 2);
assert.ok(state.peakTheoriesGenerated >= 3);

const fifteenDaysAgo = new Date();
fifteenDaysAgo.setDate(fifteenDaysAgo.getDate() - 15);
storage.set(
  "voicememory_theory_volatility",
  JSON.stringify({
    ...state,
    firstDiscoverAt: fifteenDaysAgo.toISOString(),
    discoverVisitCount: 4,
    zeroMovementVisits: 3,
    staleZeroMovementSessions: 0,
    staleSessionIds: [],
    visits: [
      ...state.visits,
      {
        at: new Date().toISOString(),
        sessionNumber: 4,
        totalTheories: 3,
        strengthenedCount: 0,
        weakenedCount: 0,
        resolvedCount: 0,
        retiredCount: 0,
        theoryChangeCount: 0,
        evidenceMovementCount: 0,
        zeroMovement: true,
        hadBaseline: true,
      },
    ],
  }),
);

sessionStorage.set("voicememory_app_session_count", "4");
recordDiscoverVolatilitySample({
  totalTheories: 3,
  strengthenedCount: 0,
  weakenedCount: 0,
  resolvedCount: 0,
  retiredCount: 0,
  theoryChangeCount: 0,
  evidenceMovementCount: 0,
  hasBaseline: true,
});

const afterStale = readTheoryVolatilityState();
assert.ok(afterStale.staleZeroMovementSessions >= 1, "expected stale zero-movement session");

const t1 = new Date("2026-01-01T12:00:00.000Z").toISOString();
const t2 = new Date("2026-01-08T12:00:00.000Z").toISOString();
const t3 = new Date("2026-01-20T12:00:00.000Z").toISOString();
storage.set(
  "voicememory_theory_volatility",
  JSON.stringify({
    version: 1,
    updatedAt: t3,
    firstDiscoverAt: t1,
    lastChangeAt: t3,
    peakTheoriesGenerated: 4,
    cumulativeStrengthened: 3,
    cumulativeWeakened: 1,
    cumulativeResolved: 1,
    cumulativeRetired: 0,
    zeroMovementVisits: 1,
    discoverVisitCount: 4,
    staleZeroMovementSessions: 0,
    staleSessionIds: [],
    visits: [
      {
        at: t1,
        sessionNumber: 1,
        totalTheories: 2,
        strengthenedCount: 1,
        weakenedCount: 0,
        resolvedCount: 0,
        retiredCount: 0,
        theoryChangeCount: 1,
        evidenceMovementCount: 0,
        zeroMovement: false,
        hadBaseline: true,
      },
      {
        at: t2,
        sessionNumber: 2,
        totalTheories: 3,
        strengthenedCount: 1,
        weakenedCount: 0,
        resolvedCount: 0,
        retiredCount: 0,
        theoryChangeCount: 1,
        evidenceMovementCount: 1,
        zeroMovement: false,
        hadBaseline: true,
      },
      {
        at: t3,
        sessionNumber: 3,
        totalTheories: 4,
        strengthenedCount: 1,
        weakenedCount: 1,
        resolvedCount: 1,
        retiredCount: 0,
        theoryChangeCount: 2,
        evidenceMovementCount: 0,
        zeroMovement: false,
        hadBaseline: true,
      },
    ],
  }),
);

const volatility = buildTheoryVolatilityReport();
assert.equal(volatility.averageDaysBetweenChanges, 9.5);
assert.equal(volatility.medianDaysBetweenChanges, 9.5);
assert.ok(volatility.strengthenedCount >= 3);
assert.ok(volatility.weakenedCount >= 1);
assert.ok(volatility.resolvedCount >= 1);
assert.ok(volatility.insightLines.length >= 2);
assert.ok(
  ["healthy", "quiet", "stale", "dead_feed_risk"].includes(volatility.riskLabel),
);

const discovery = buildTheoryDiscoveryReport(repeating);
assert.ok(discovery.volatility);
assert.equal(discovery.volatility.riskLabelDisplay, volatility.riskLabelDisplay);

const required = [
  "lib/discover/theory-volatility.ts",
  "components/internal/TheoryVolatilityPanel.tsx",
  "components/internal/TheoryDiscoveryPanel.tsx",
  "components/discover/TheoryChangeFeed.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

const panelSrc = fs.readFileSync(
  path.join(ROOT, "components/internal/TheoryDiscoveryPanel.tsx"),
  "utf8",
);
if (!panelSrc.includes("TheoryVolatilityPanel")) {
  failures.push("TheoryDiscoveryPanel must render TheoryVolatilityPanel");
}

const volatilityPanelSrc = fs.readFileSync(
  path.join(ROOT, "components/internal/TheoryVolatilityPanel.tsx"),
  "utf8",
);
if (!volatilityPanelSrc.includes("Theory Volatility")) {
  failures.push("TheoryVolatilityPanel must include Theory Volatility heading");
}

const feedSrc = fs.readFileSync(
  path.join(ROOT, "components/discover/TheoryChangeFeed.tsx"),
  "utf8",
);
if (!feedSrc.includes("recordDiscoverVolatilitySample")) {
  failures.push("TheoryChangeFeed must record discover volatility samples");
}

if (failures.length > 0) {
  console.error("validate-theory-volatility failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-theory-volatility ok");
