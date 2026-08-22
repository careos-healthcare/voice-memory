#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

function entry(id, day, transcript, reflection = {}) {
  const date = new Date(`2026-02-${String(day).padStart(2, "0")}T12:00:00.000Z`);
  return {
    id,
    createdAt: date.toISOString(),
    transcript,
    reflection: {
      mood: "tense",
      emotionalIntensity: 6,
      recurringThemes: ["work", "avoidance"],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
      exactLanguagePattern: "",
      repeatedSignal: "",
      ...reflection,
    },
    durationSeconds: 40,
  };
}

const twoEcho = [
  entry("e1", 1, "I keep saying I will start Monday but I never do."),
  entry("e2", 5, "I keep avoiding the conversation with my manager."),
];

const fiveEntries = [
  ...twoEcho,
  entry("e3", 10, "I keep circling the same worry about money and work."),
  entry("e4", 15, "Maybe I will eventually tell them — I don't know."),
  entry("e5", 20, "I should have spoken up but I keep waiting to quit."),
];

const { buildMiniWowReport } = await import("../packages/shared/lib/blind-spots/mini-wow.ts");
const { MINI_WOW_COPY } = await import("../packages/shared/lib/blind-spots/mini-wow-copy.ts");
const { BLIND_SPOT_MIN_REFLECTIONS } = await import("../packages/shared/lib/blind-spots/blind-spot-copy.ts");
const { buildPatternCandidatesRelaxed } = await import("../packages/shared/lib/patterns/pattern-engine.ts");

assert.equal(MINI_WOW_COPY.disclaimer, "Early signal, not a conclusion");
assert.ok(MINI_WOW_COPY.progressTowardReview(2).includes("2/5"));
assert.equal(BLIND_SPOT_MIN_REFLECTIONS, 5);

const atTwo = buildMiniWowReport(twoEcho);
assert.ok(["none", "echo"].includes(atTwo.tier), `unexpected tier at 2: ${atTwo.tier}`);
if (atTwo.tier === "echo") {
  assert.equal(atTwo.title, MINI_WOW_COPY.echoTitle);
  assert.equal(atTwo.showPanel, true);
  assert.ok(atTwo.body.length > 10);
}

const atFive = buildMiniWowReport(fiveEntries);
assert.equal(atFive.tier, "unlocked");
assert.equal(atFive.showPanel, false);
assert.ok(atFive.progressLabel.includes("5/5"));

const atFour = buildMiniWowReport(fiveEntries.slice(0, 4));
assert.ok(["forming", "preview", "echo", "none"].includes(atFour.tier));
assert.ok(atFour.reflectionCount === 4);

const one = buildMiniWowReport([twoEcho[0]]);
assert.equal(one.tier, "first");
assert.equal(one.showPanel, true);
assert.ok(one.body.includes("need repeated evidence"), "1 reflection must not overclaim");
assert.ok(!/\byou always\b/i.test(one.body));
assert.equal(one.panelTitle, MINI_WOW_COPY.panelTitle);

const relaxed = buildPatternCandidatesRelaxed(fiveEntries);
for (const insight of relaxed) {
  assert.equal(insight.specificity.isWeakOrGeneric, false);
}

const genericOnly = [
  entry("g1", 1, "Today was fine."),
  entry("g2", 2, "Another okay day."),
];
const weak = buildMiniWowReport(genericOnly);
assert.equal(weak.showPanel, false, "generic reflections should not surface mini-wow");

const progressTwo = buildMiniWowReport(twoEcho);
if (progressTwo.showPanel) {
  const cautious =
    /\bmay\b|\bpossible\b|\bearly\b|\bworth noticing\b/i.test(
      `${progressTwo.title} ${progressTwo.body}`,
    ) || progressTwo.disclaimer.includes("Early signal");
  assert.ok(cautious, "2–4 copy must stay cautious");
  assert.ok(progressTwo.clueType !== "none");
}

const { buildImmediateLearningSignal } = await import("../packages/shared/lib/blind-spots/mini-wow.ts");
assert.equal(buildImmediateLearningSignal([twoEcho[0]]).tier, "first");

const panelSrc = fs.readFileSync(
  path.join(ROOT, "apps/web/components/blind-spots/MiniWowPanel.tsx"),
  "utf8",
);
if (!panelSrc.includes("panelTitle")) {
  failures.push("MiniWowPanel must render report.panelTitle");
}

const required = [
  "packages/shared/types/mini-wow.ts",
  "packages/shared/lib/blind-spots/mini-wow.ts",
  "packages/shared/lib/blind-spots/mini-wow-copy.ts",
  "apps/web/components/blind-spots/MiniWowPanel.tsx",
  "apps/web/app/memory/page.tsx",
  "apps/web/components/Recorder.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

const memorySrc = fs.readFileSync(path.join(ROOT, "apps/web/app/memory/page.tsx"), "utf8");
if (!memorySrc.includes("MiniWowPanel")) {
  failures.push("memory page must render MiniWowPanel");
}

const recorderSrc = fs.readFileSync(path.join(ROOT, "apps/web/components/Recorder.tsx"), "utf8");
if (!recorderSrc.includes("MiniWowPanel")) {
  failures.push("Recorder must render MiniWowPanel after save");
}

const entrySrc = fs.readFileSync(path.join(ROOT, "apps/web/app/entry/[id]/page.tsx"), "utf8");
if (!entrySrc.includes("MiniWowPanel")) {
  failures.push("entry page must render MiniWowPanel on fresh save");
}

if (!fs.readFileSync(path.join(ROOT, "package.json"), "utf8").includes("validate:mini-wow")) {
  failures.push("package.json missing validate:mini-wow");
}

if (failures.length > 0) {
  console.error("validate-mini-wow failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-mini-wow ok");
