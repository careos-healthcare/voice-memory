#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const failures = [];

function fail(msg) {
  failures.push(msg);
}

const FORBIDDEN =
  /\b(diagnos|disorder|patholog|clinical|therapy|counsel|coach|treatment|you are always|guaranteed|certainly means)\b/i;

const storage = new Map();
globalThis.window = globalThis;
globalThis.window.location = { pathname: "/" };
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

const required = [
  "packages/shared/types/archive-value.ts",
  "packages/shared/lib/product/archive-value-progress.ts",
  "packages/shared/lib/product/archive-value-copy.ts",
  "packages/shared/lib/product/archive-value-metrics.ts",
  "apps/web/components/product/ArchiveValueBanner.tsx",
  "apps/web/components/product/ReflectionValueLadder.tsx",
  "apps/web/components/product/ArchiveChangedMessage.tsx",
  "apps/web/components/internal/ArchiveValueProgressPanel.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

function makeEntries(count) {
  return Array.from({ length: count }, (_, i) => ({
    id: `e${i + 1}`,
    createdAt: new Date(`2026-01-${String(i + 1).padStart(2, "0")}T12:00:00.000Z`).toISOString(),
    transcript: `I keep circling the same worry about work and money entry ${i + 1}.`,
    reflection: {
      mood: "tense",
      emotionalIntensity: 6,
      recurringThemes: ["work", "money"],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
    },
    durationSeconds: 40,
  }));
}

const {
  stageForReflectionCount,
  buildArchiveValueSnapshot,
  buildArchiveChangedMessage,
} = await import("../../packages/shared/lib/product/archive-value-progress.ts");
const { ARCHIVE_VALUE_STAGE_COPY, REFLECTION_VALUE_LADDER } = await import(
  "../../packages/shared/lib/product/archive-value-copy.ts"
);
const {
  buildArchiveValueMetricsReport,
  trackArchiveValueBannerShown,
  trackArchiveValueCtaClicked,
  trackReflectionLadderSeen,
  clearArchiveValueMetricsForEval,
  ARCHIVE_VALUE_EVENTS,
  observeArchiveValueStageMilestones,
} = await import("../../packages/shared/lib/product/archive-value-metrics.ts");

assert.equal(stageForReflectionCount(1), "one_data_point");
assert.equal(stageForReflectionCount(2), "possible_repeat");
assert.equal(stageForReflectionCount(3), "pattern_forming");
assert.equal(stageForReflectionCount(4), "theory_under_review");
assert.equal(stageForReflectionCount(5), "pattern_review_unlocked");
assert.equal(stageForReflectionCount(10), "pattern_review_unlocked");

assert.ok(ARCHIVE_VALUE_STAGE_COPY.one_data_point.valueCopy.includes("One data point"));
assert.ok(ARCHIVE_VALUE_STAGE_COPY.possible_repeat.valueCopy.includes("possible repeat"));
assert.ok(ARCHIVE_VALUE_STAGE_COPY.pattern_forming.valueCopy.includes("Evidence"));
assert.ok(ARCHIVE_VALUE_STAGE_COPY.theory_under_review.valueCopy.includes("theory"));
assert.ok(
  ARCHIVE_VALUE_STAGE_COPY.pattern_review_unlocked.valueCopy.toLowerCase().includes(
    "working theory",
  ),
);

const at4 = buildArchiveValueSnapshot(makeEntries(4));
assert.equal(at4.stage, "theory_under_review");
assert.ok(at4.nextMilestoneCopy.includes("1 more reflection"));
assert.equal(at4.ctaLabel, "Add another reflection");
assert.equal(at4.ctaHref, "/#recorder");

const at5 = buildArchiveValueSnapshot(makeEntries(5));
assert.equal(at5.stage, "pattern_review_unlocked");
assert.equal(at5.ctaLabel, "Open first working theory");
assert.equal(at5.ctaHref, "/blind-spots");

assert.equal(REFLECTION_VALUE_LADDER.length, 5);

const changed = buildArchiveChangedMessage(makeEntries(3));
assert.ok(changed.includes("3 reflections"));
assert.ok(
  changed.includes("compare") ||
    changed.includes("pattern") ||
    changed.includes("Evidence") ||
    changed.includes("reflection"),
);

clearArchiveValueMetricsForEval();
observeArchiveValueStageMilestones(1);
observeArchiveValueStageMilestones(2);
observeArchiveValueStageMilestones(3);
observeArchiveValueStageMilestones(4);
observeArchiveValueStageMilestones(5);
trackArchiveValueBannerShown(3, "pattern_forming");
trackArchiveValueCtaClicked(3, "pattern_forming");
trackReflectionLadderSeen(3);

const metrics = buildArchiveValueMetricsReport();
assert.ok(metrics.stageCounts.pattern_forming >= 1);
assert.ok(metrics.bannerShownCount >= 1);
assert.ok(metrics.ladderSeenCount >= 1);
assert.equal(metrics.progressionRates.fourToFive, 100);

const bannerSrc = fs.readFileSync(
  path.join(ROOT, "apps/web/components/product/ArchiveValueBanner.tsx"),
  "utf8",
);
assert.ok(bannerSrc.includes("ctaLabel"), "banner must render snapshot CTA");

const progressSrc = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/product/archive-value-progress.ts"),
  "utf8",
);
assert.ok(progressSrc.includes("Add another reflection"));
assert.ok(progressSrc.includes("Open first working theory"));

const claritySrc = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/product/product-clarity-copy.ts"),
  "utf8",
);
const archiveValueCopySrc = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/product/archive-value-copy.ts"),
  "utf8",
);
assert.ok(
  claritySrc.includes("ChatGPT can answer a conversation") ||
    claritySrc.includes("ChatGPT helps you think today") ||
    claritySrc.includes("ChatGPT answers today") ||
    archiveValueCopySrc.includes("ChatGPT helps with today's question"),
);
assert.ok(
  claritySrc.includes("Each moment gives ArchiveMe") ||
    archiveValueCopySrc.includes("Each reflection gives ArchiveMe"),
);

for (const rel of [
  "apps/web/app/page.tsx",
  "apps/web/app/memory/page.tsx",
  "apps/web/app/discover/page.tsx",
  "apps/web/app/blind-spots/page.tsx",
  "apps/web/components/Recorder.tsx",
  "apps/web/app/entry/[id]/page.tsx",
]) {
  const src = fs.readFileSync(path.join(ROOT, rel), "utf8");
  if (!src.includes("ArchiveValueBanner")) fail(`${rel} must wire ArchiveValueBanner`);
}

const retentionSrc = fs.readFileSync(
  path.join(ROOT, "apps/web/app/internal/retention-discovery/page.tsx"),
  "utf8",
);
if (!retentionSrc.includes("ArchiveValueProgressPanel")) {
  fail("retention-discovery must wire ArchiveValueProgressPanel");
}

if (/buildBlindSpotReview|rankBlindSpotCandidates|new PatternEngine/i.test(progressSrc)) {
  fail("archive-value-progress must not add new analysis engines");
}

const headerSrc = fs.existsSync(path.join(ROOT, "apps/web/components/SiteHeader.tsx"))
  ? fs.readFileSync(path.join(ROOT, "apps/web/components/SiteHeader.tsx"), "utf8")
  : "";
if (headerSrc.includes("/internal/")) {
  fail("SiteHeader must not link internal routes");
}

const pageSrc = fs.readFileSync(path.join(ROOT, "apps/web/app/page.tsx"), "utf8");
if (pageSrc.includes('href="/internal/')) {
  fail("homepage must not link internal routes in nav");
}

for (const rel of ["packages/shared/lib/product/archive-value-copy.ts", "apps/web/components/product/ArchiveValueBanner.tsx"]) {
  if (FORBIDDEN.test(fs.readFileSync(path.join(ROOT, rel), "utf8"))) {
    fail(`forbidden language in ${rel}`);
  }
}

assert.ok(Object.values(ARCHIVE_VALUE_EVENTS).includes("archive_value_banner_shown"));

if (failures.length > 0) {
  console.error("validate-archive-value-progress failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-archive-value-progress ok");
