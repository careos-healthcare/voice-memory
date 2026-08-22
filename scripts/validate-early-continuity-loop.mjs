#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const requiredFiles = [
  "packages/shared/lib/continuity/early-resurfacing-magic.ts",
  "packages/shared/lib/continuity/memory-starts-immediately.ts",
  "packages/shared/lib/product/pro-framing.ts",
];

for (const rel of requiredFiles) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

const memoryStarts = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/continuity/memory-starts-immediately.ts"),
  "utf8",
);
const buildLines = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/continuity/build-continuity-lines.ts"),
  "utf8",
);
const quiet = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/refinement/quiet-presentation.ts"),
  "utf8",
);
const afterSave = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/reflection/after-save-continuity.ts"),
  "utf8",
);

if (!memoryStarts.includes("FIRST_REFLECTION_SAVED_LINE")) {
  failures.push("memory-starts must define first-save line");
}
if (!memoryStarts.includes("NOTHING_RETURNED_YET_LINE")) {
  failures.push("memory-starts must define nothing-returned line");
}
if (!buildLines.includes("resolveEarlyPreMicLine")) {
  failures.push("preMic must use resolveEarlyPreMicLine");
}
if (buildLines.includes("resolveContinuityLineOrFallback")) {
  failures.push("preMic must not use generic continuity fallback");
}
if (buildLines.includes("HOMEPAGE_LINES")) {
  failures.push("build-continuity-lines must not use generic homepage fallbacks");
}
if (!quiet.includes("preMicContinuityLine")) {
  failures.push("quiet-presentation must use preMicContinuityLine");
}
if (quiet.includes("homepageContinuationNotes")) {
  failures.push("quiet-presentation must not stack modules before mic");
}
if (!afterSave.includes("postSaveAcknowledgmentLine")) {
  failures.push("after-save must use tiered post-save acknowledgment");
}

const grindRe =
  /\b(keep recording|unlock later|build your streak|streak counter|unlock your|grind|level up|productivity score)\b/i;
const scanDirs = ["app", "components", "packages/shared/lib/product", "packages/shared/lib/continuity", "packages/shared/lib/onboarding"];
for (const dir of scanDirs) {
  const full = path.join(ROOT, dir);
  if (!fs.existsSync(full)) continue;
  const walk = (d) => {
    for (const name of fs.readdirSync(d)) {
      const p = path.join(d, name);
      if (fs.statSync(p).isDirectory()) {
        if (!p.includes(`${path.sep}debug${path.sep}`)) walk(p);
        continue;
      }
      if (!/\.(tsx|ts)$/.test(name)) continue;
      const src = fs.readFileSync(p, "utf8");
      if (!grindRe.test(src)) continue;
      const rel = path.relative(ROOT, p);
      if (
        rel.includes("interruption-timing") ||
        rel.includes("habit-storage") ||
        rel.includes("trust-copy") ||
        rel.includes("safety/page") ||
        rel.includes("gentle-return-prompts") ||
        rel.includes("onboarding-restraint") ||
        rel.includes("-restraint") ||
        src.includes("no streak") ||
        src.includes("not pressures you") ||
        src.includes("no penalty")
      ) {
        continue;
      }
      failures.push(`grind language in ${rel}`);
    }
  };
  walk(full);
}

const proFraming = fs.readFileSync(path.join(ROOT, "packages/shared/lib/product/pro-framing.ts"), "utf8");
if (!proFraming.includes("Export stays available") && !proFraming.includes("Export JSON")) {
  failures.push("pro-framing must keep export secondary");
}
if (proFraming.toLowerCase().includes("unlock your")) {
  failures.push("pro-framing must not use unlock-your framing");
}

const magicMod = await import(
  pathToFileURL(path.join(ROOT, "packages/shared/lib/continuity/early-resurfacing-magic.ts")).href
);
const memoryMod = await import(
  pathToFileURL(path.join(ROOT, "packages/shared/lib/continuity/memory-starts-immediately.ts")).href
);
const gateMod = await import(
  pathToFileURL(path.join(ROOT, "packages/shared/lib/continuity/continuity-quality-gate.ts")).href
);

if (magicMod.pickEarlyResurfacingMagicLine([]) !== null) {
  failures.push("early magic must be null with zero entries");
}

const emptyReflection = {
  mood: "neutral",
  emotionalIntensity: 5,
  recurringThemes: [],
  hiddenConcern: "",
  positiveSignal: "",
  recommendation: "",
};
const junkLine = magicMod.pickEarlyResurfacingMagicLine([
  {
    id: "1",
    createdAt: new Date().toISOString(),
    transcript: "thank you for watching",
    durationSeconds: 10,
    reflection: emptyReflection,
  },
  {
    id: "2",
    createdAt: new Date().toISOString(),
    transcript: "this is just a test",
    durationSeconds: 10,
    reflection: emptyReflection,
  },
]);
if (junkLine !== null) {
  failures.push("early magic must not surface junk transcripts");
}

const oneLine = memoryMod.resolveEarlyPreMicLine([
  {
    id: "a",
    createdAt: "2026-01-01T12:00:00.000Z",
    transcript:
      "I keep thinking about starting over with my brother and what I should say tomorrow.",
    durationSeconds: 40,
    reflection: { ...emptyReflection, recurringThemes: ["family"] },
  },
]);
if (oneLine !== null) {
  failures.push("pre-mic must be null with only one quality reflection");
}

if (gateMod.gateContinuityLine("thank you for watching") !== null) {
  failures.push("continuity gate must block thank you for watching");
}

if (failures.length > 0) {
  console.error("validate-early-continuity-loop failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-early-continuity-loop ok");
