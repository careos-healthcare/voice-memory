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
  "packages/shared/types/archive-as-product-validation.ts",
  "packages/shared/lib/founder-test/archive-as-product-validation.ts",
  "packages/shared/lib/founder-test/archive-as-product-metrics.ts",
  "packages/shared/lib/metrics/archive-as-product-events.ts",
  "apps/web/components/internal/ArchiveAsProductValidationPanel.tsx",
  "apps/web/components/archive/EvidenceArchiveHome.tsx",
  "apps/web/components/discover/TheoryChangeFeed.tsx",
  "apps/web/components/Recorder.tsx",
  "apps/web/app/internal/founder-test/page.tsx",
  "apps/web/app/internal/archive-belief/page.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts["validate:archive-as-product"]) {
  fail("package.json missing validate:archive-as-product script");
}

const home = fs.readFileSync(
  path.join(ROOT, "apps/web/components/archive/EvidenceArchiveHome.tsx"),
  "utf8",
);
if (!home.includes("trackArchiveProductHomeOpened")) {
  fail("EvidenceArchiveHome must track archive product home opens");
}

const discover = fs.readFileSync(
  path.join(ROOT, "apps/web/components/discover/TheoryChangeFeed.tsx"),
  "utf8",
);
if (!discover.includes("trackDiscoverProductOpened")) {
  fail("TheoryChangeFeed must track post-five Discover opens");
}

const recorder = fs.readFileSync(path.join(ROOT, "apps/web/components/Recorder.tsx"), "utf8");
if (!recorder.includes("markPostFiveReflectionMilestone")) {
  fail("Recorder must mark post-five milestone");
}

const founderPage = fs.readFileSync(
  path.join(ROOT, "apps/web/app/internal/founder-test/page.tsx"),
  "utf8",
);
if (!founderPage.includes("Archive before Discover")) {
  fail("founder-test page must reference Archive-before-Discover gate");
}

const {
  ARCHIVE_AS_PRODUCT_CRITERIA,
  ARCHIVE_AS_PRODUCT_MAIN_QUESTION,
  classifyProductDescriptionVerbatim,
} = await import("../packages/shared/lib/founder-test/archive-as-product-validation.ts");
const { buildArchiveAsProductValidationReport } = await import(
  "../packages/shared/lib/founder-test/archive-as-product-metrics.ts"
);
const {
  ARCHIVE_AS_PRODUCT_EVENT_NAMES,
  clearArchiveAsProductEventsForEval,
  trackArchiveProductHomeOpened,
  trackDiscoverProductOpened,
} = await import("../packages/shared/lib/metrics/archive-as-product-events.ts");
const { clearFounderTestSessionsForEval, updateFounderTestSession, createFounderTestParticipant } =
  await import("../packages/shared/lib/founder-test/founder-test-storage.ts");

assert.equal(ARCHIVE_AS_PRODUCT_CRITERIA.length, 4);

assert.equal(
  classifyProductDescriptionVerbatim("It's my archive — I check what it believes"),
  "archive_model",
);
assert.equal(
  classifyProductDescriptionVerbatim("Just a voice journal with AI insights"),
  "journal_mode",
);

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
clearFounderTestSessionsForEval();

assert.ok(typeof trackArchiveProductHomeOpened === "function");
assert.ok(typeof trackDiscoverProductOpened === "function");
assert.equal(Object.keys(ARCHIVE_AS_PRODUCT_EVENT_NAMES).length, 4);

const { participant } = createFounderTestParticipant("Archive gate test");
updateFounderTestSession(participant.id, {
  productDescriptionCategory: "archive_model",
  openedArchiveBeforeDiscoverPostFive: true,
  reflectionSixFeltStronger: true,
  voluntaryArchiveReturn: true,
});

const report = buildArchiveAsProductValidationReport();
assert.ok(report.criteria.length === 4);
assert.ok(report.mainQuestion === ARCHIVE_AS_PRODUCT_MAIN_QUESTION);
assert.ok(["strong", "weak", "mixed", "insufficient_data"].includes(report.verdict));

const belief = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/founder-test/belief-reframing-validation.ts"),
  "utf8",
);
if (!belief.includes("archive_before_discover")) {
  fail("belief-reframing must use archive_before_discover criterion");
}

if (failures.length) {
  console.error("validate:archive-as-product failed:\n" + failures.map((f) => `  - ${f}`).join("\n"));
  process.exit(1);
}

console.log("validate:archive-as-product OK");
