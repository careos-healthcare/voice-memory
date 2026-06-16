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

const FORBIDDEN_RE =
  /\b(diagnosis|disorder|therapy|treatment|trauma label|rejection sensitivity)\b/i;

function baseReflection(overrides = {}) {
  return {
    mood: "tense",
    emotionalIntensity: 6,
    recurringThemes: ["work"],
    hiddenConcern: "",
    positiveSignal: "",
    recommendation: "",
    ...overrides,
  };
}

function entry(id, day, transcript, reflection = {}) {
  const date = new Date(`2026-01-${String(day).padStart(2, "0")}T12:00:00.000Z`);
  return {
    id,
    createdAt: date.toISOString(),
    transcript,
    reflection: baseReflection(reflection),
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

const { buildTheoriesForEval, buildTheoryTrackerReport } = await import(
  "../lib/theories/theory-generation.ts"
);
const { clearTheorySnapshotsForEval } = await import("../lib/theories/theory-snapshots.ts");
const {
  clearTheoryFeedbackForEval,
  saveTheoryFeedback,
  readAllTheoryFeedback,
} = await import("../lib/theories/theory-feedback.ts");
const { clearTheoryEventsForEval, appendTheoryEventForEval, readAllTheoryEvents } =
  await import("../lib/theories/theory-events.ts");
const { buildTheoryDiscoveryReport } = await import(
  "../lib/theories/theory-discovery-report.ts"
);
const { FORBIDDEN_THEORY_OUTPUT } = await import("../lib/theories/theory-copy.ts");
const { THEORY_PAGE } = await import("../lib/theories/theory-copy.ts");
const {
  buildTheoryUncertaintyView,
  buildTheoryUncertaintyFromTheory,
  buildTheoryUncertaintyFromChangeItem,
  THEORY_UNCERTAINTY_COPY,
} = await import("../lib/theories/theory-uncertainty.ts");

clearTheorySnapshotsForEval();
clearTheoryFeedbackForEval();
clearTheoryEventsForEval();

const theories = buildTheoriesForEval(repeating);
assert.ok(theories.length >= 1, "expected at least one theory from fixture reflections");

const VALID_STATUS = new Set([
  "active",
  "strengthening",
  "weakening",
  "resolved",
  "retired",
]);
for (const t of theories) {
  assert.ok(t.confidence >= 0 && t.confidence <= 100, `confidence out of range: ${t.confidence}`);
  assert.ok(VALID_STATUS.has(t.status), `invalid status: ${t.status}`);
  assert.ok(t.whatChanged.length >= 1, `missing whatChanged for ${t.id}`);
  assert.ok(t.statement.length > 10);
  assert.ok(!FORBIDDEN_RE.test(t.statement), `forbidden word in statement: ${t.statement}`);
  assert.ok(!FORBIDDEN_THEORY_OUTPUT.test(t.statement));
  for (const line of t.whatChanged) {
    assert.ok(!FORBIDDEN_RE.test(line));
  }
}

const report = buildTheoryTrackerReport(repeating);
assert.ok(
  report.active.length +
    report.strengthening.length +
    report.weakening.length +
    report.resolved.length +
    report.retired.length ===
    report.all.length,
);

const first = theories[0];
saveTheoryFeedback({
  theoryId: first.id,
  reaction: "surprising",
  statement: first.statement,
  source: first.source,
  confidence: first.confidence,
});
assert.equal(readAllTheoryFeedback().length, 1);

appendTheoryEventForEval("theory_viewed", { theoryId: first.id });
appendTheoryEventForEval("theory_expanded", { theoryId: first.id });
assert.ok(readAllTheoryEvents().length >= 2);

const discovery = buildTheoryDiscoveryReport(repeating);
assert.ok(discovery.totalTheories >= 1);
assert.ok(typeof discovery.resolvedCount === "number");
assert.ok(typeof discovery.retiredCount === "number");
assert.ok(discovery.sourceBreakdown.length === 4);
assert.ok(discovery.volatility);
assert.ok(
  ["healthy", "quiet", "stale", "dead_feed_risk"].includes(discovery.volatility.riskLabel),
);

const pageCopy = [
  THEORY_PAGE.title,
  THEORY_PAGE.lead,
  THEORY_PAGE.disclaimer,
].join(" ");
assert.ok(!FORBIDDEN_RE.test(pageCopy));

const required = [
  "types/theory.ts",
  "lib/theories/theory-generation.ts",
  "lib/theories/theory-feedback.ts",
  "lib/theories/theory-events.ts",
  "lib/theories/theory-snapshots.ts",
  "lib/theories/theory-discovery-report.ts",
  "app/theories/page.tsx",
  "app/internal/theory-discovery/page.tsx",
  "components/theories/TheoriesView.tsx",
  "components/theories/TheoryCard.tsx",
  "components/theories/TheoryUnderReviewPanel.tsx",
  "lib/theories/theory-uncertainty.ts",
  "lib/theories/theory-resolution.ts",
  "lib/discover/theory-volatility.ts",
  "components/internal/TheoryVolatilityPanel.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    failures.push(`missing ${rel}`);
  }
}

if (!fs.existsSync(path.join(ROOT, "app/theories/page.tsx"))) {
  failures.push("/theories route missing");
}
if (!fs.existsSync(path.join(ROOT, "app/internal/theory-discovery/page.tsx"))) {
  failures.push("/internal/theory-discovery route missing");
}

const theoriesPage = fs.readFileSync(path.join(ROOT, "app/theories/page.tsx"), "utf8");
if (!theoriesPage.includes("THEORY_PAGE") || !theoriesPage.includes("TheoriesView")) {
  failures.push("theories page must wire THEORY_PAGE copy and TheoriesView");
}
assert.equal(THEORY_PAGE.title, "Archive beliefs");

const uncertainty = buildTheoryUncertaintyFromTheory(first);
assert.equal(uncertainty.panelLead, THEORY_UNCERTAINTY_COPY.panelLead);
assert.equal(uncertainty.panelTitle, "Theory under review");
assert.ok(uncertainty.supportingCount >= 0);
assert.ok(uncertainty.contradictingCount >= 0);
assert.ok(uncertainty.missingEvidenceCount >= 0);
assert.ok(uncertainty.missingEvidenceNote.length > 0);
assert.ok(
  [
    "strengthening",
    "weakening",
    "unresolved",
    "under_review",
    "resolved",
    "retired",
  ].includes(uncertainty.displayStatus),
);
assert.ok(!FORBIDDEN_RE.test(uncertainty.panelLead));
assert.ok(!/\b(coaching|diagnosis|certainly|guaranteed)\b/i.test(uncertainty.panelLead));

const mixedInput = {
  supportingEvidenceCount: 4,
  contradictingEvidenceCount: 2,
  confidence: 48,
  status: "active",
};
const mixedView = buildTheoryUncertaintyView(mixedInput);
assert.equal(mixedView.displayStatus, "unresolved");
assert.ok(mixedView.missingEvidenceCount === 0);

const thinInput = {
  supportingEvidenceCount: 2,
  contradictingEvidenceCount: 0,
  confidence: 40,
  status: "active",
};
const thinView = buildTheoryUncertaintyView(thinInput);
assert.equal(thinView.displayStatus, "under_review");
assert.equal(thinView.missingEvidenceCount, 1);

const changeItem = {
  theoryId: first.id,
  statement: first.statement,
  confidence: first.confidence,
  confidenceDelta: 2,
  updatedAt: first.updatedAt,
  shortReason: "Test",
  category: "strengthened",
  source: first.source,
  status: first.status,
  supportingEvidenceCount: first.supportingEvidenceCount,
  contradictingEvidenceCount: first.contradictingEvidenceCount,
};
const changeUncertainty = buildTheoryUncertaintyFromChangeItem(changeItem);
assert.equal(changeUncertainty.supportingCount, first.supportingEvidenceCount);

const theoryCardSrc = fs.readFileSync(
  path.join(ROOT, "components/theories/TheoryCard.tsx"),
  "utf8",
);
const changeCardSrc = fs.readFileSync(
  path.join(ROOT, "components/discover/TheoryChangeItemCard.tsx"),
  "utf8",
);
if (!theoryCardSrc.includes("TheoryUnderReviewPanel")) {
  failures.push("TheoryCard must render TheoryUnderReviewPanel");
}
if (!changeCardSrc.includes("TheoryUnderReviewPanel")) {
  failures.push("TheoryChangeItemCard must render TheoryUnderReviewPanel");
}
if (!theoryCardSrc.includes("TheoryUnderReviewPanel")) {
  failures.push("TheoryCard must include TheoryUnderReviewPanel");
}

const panelSrc = fs.readFileSync(
  path.join(ROOT, "components/theories/TheoryUnderReviewPanel.tsx"),
  "utf8",
);
for (const id of [
  "theory-supporting-count",
  "theory-contradicting-count",
  "theory-missing-count",
  "theory-missing-note",
  "theory-confidence-score",
  "theory-display-status",
]) {
  if (!panelSrc.includes(id)) {
    failures.push(`TheoryUnderReviewPanel missing data-testid ${id}`);
  }
}

if (!fs.existsSync(path.join(ROOT, "lib/theories/theory-uncertainty.ts"))) {
  failures.push("missing lib/theories/theory-uncertainty.ts");
}

if (failures.length > 0) {
  console.error("validate-theory-tracker failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-theory-tracker ok");
