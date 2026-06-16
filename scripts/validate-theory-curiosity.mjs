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

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

const required = [
  "types/theory-curiosity-engine.ts",
  "lib/metrics/theory-curiosity-engine.ts",
  "lib/discover/theory-movement-feed.ts",
  "lib/discover/theory-movement-copy.ts",
  "components/discover/TheoryMovementFeed.tsx",
  "components/internal/TheoryCuriosityEnginePanel.tsx",
  "components/theories/TheoryCuriosityPrompt.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const discoverCopy = read("lib/theories/personal-theory-copy.ts");
if (!discoverCopy.includes("What your archive currently believes")) {
  fail("discover headline missing");
}

const movement = read("lib/discover/theory-movement-copy.ts");
for (const phrase of [
  "The archive has become more certain.",
  "Recent reflections challenged this belief",
  "The archive no longer sees enough evidence.",
  "Recent reflections contradict this theory",
  "Recent evidence no longer supports it",
]) {
  if (!movement.includes(phrase)) fail(`movement copy missing: ${phrase}`);
}

const curiosity = read("lib/metrics/theory-curiosity.ts");
if (!curiosity.includes("voicememory_theory_curiosity")) {
  fail("curiosity storage key missing");
}
if (!curiosity.includes("curious whether it had changed")) {
  fail("pre-open question missing");
}

const engine = read("lib/metrics/theory-curiosity-engine.ts");
if (!engine.includes("leading retention indicator")) {
  fail("leading indicator line missing");
}
if (!engine.includes("paywall_click")) fail("paywall funnel step missing");
if (!engine.includes("return_7d")) fail("return funnel step missing");

const feedUi = read("components/discover/TheoryChangeFeed.tsx");
if (!feedUi.includes("TheoryMovementFeed")) {
  fail("TheoryChangeFeed must render TheoryMovementFeed");
}

const antiGamification = read("lib/metrics/theory-curiosity-engine.ts");
if (/\bstreak\b|\bgamif/i.test(antiGamification)) {
  fail("curiosity engine must not use streaks or gamification");
}
if (!antiGamification.includes("No streaks")) {
  fail("curiosity engine must document no-streaks policy");
}

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

const { buildTheoryMovementFeed } = await import("../lib/discover/theory-movement-feed.ts");
const { buildTheoryChangeFeed } = await import("../lib/discover/theory-change-feed.ts");
const { buildTheoryResolutionFeed } = await import("../lib/discover/theory-resolution-feed.ts");
const { clearTheoryCuriosityForEval, saveTheoryCuriosityAnswer } = await import(
  "../lib/metrics/theory-curiosity.ts"
);
const {
  buildTheoryCuriosityEngineReport,
  isCuriousAnswer,
} = await import("../lib/metrics/theory-curiosity-engine.ts");
const { trackTheoryEvent, THEORY_EVENTS, clearTheoryEventsForEval } = await import(
  "../lib/theories/theory-events.ts"
);
const { trackLocalEvent } = await import("../lib/local-analytics.ts");

function entry(id, day, transcript) {
  const month = day > 28 ? "02" : "01";
  const d = day > 28 ? day - 28 : day;
  return {
    id,
    createdAt: new Date(`2026-${month}-${String(d).padStart(2, "0")}T12:00:00.000Z`).toISOString(),
    transcript,
    reflection: {
      mood: "tense",
      emotionalIntensity: 6,
      recurringThemes: ["work", "relationships"],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
    },
    durationSeconds: 40,
  };
}

const entries = [
  entry("e1", 1, "At work I keep avoiding the hard conversation."),
  entry("e2", 8, "My partner says I shut down — I thought I would speak up but I never do."),
  entry("e3", 16, "I said I would start Monday and I keep doing the same thing."),
  entry("e4", 24, "Money stress and relationship tension keep showing up."),
  entry("e5", 32, "I keep circling the same worry about work and relationships."),
];

const change = buildTheoryChangeFeed(entries);
const resolution = buildTheoryResolutionFeed(entries);
const movementReport = buildTheoryMovementFeed(change, resolution);

if (change.hasBaseline) {
  for (const item of movementReport.movements) {
    assert.ok(item.headline.length > 0);
    assert.ok(item.why.length > 0);
  }
}

assert.equal(isCuriousAnswer("yes"), true);
assert.equal(isCuriousAnswer("maybe"), true);
assert.equal(isCuriousAnswer("no"), false);

clearTheoryCuriosityForEval();
clearTheoryEventsForEval();
saveTheoryCuriosityAnswer("yes");
trackTheoryEvent(THEORY_EVENTS.discoverOpened, {});
trackLocalEvent("upgrade_clicked", {});

const report = buildTheoryCuriosityEngineReport();
assert.ok(report.funnel.length >= 5);
assert.equal(report.funnel[0]?.id, "curiosity");
assert.ok(report.leadingIndicatorLine.includes("leading retention"));

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts?.["validate:theory-curiosity"]) {
  fail("package.json missing validate:theory-curiosity");
}

if (failures.length) {
  console.error("validate-theory-curiosity failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-theory-curiosity ok");
