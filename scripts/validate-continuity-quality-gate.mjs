#!/usr/bin/env node
import path from "node:path";
import { fileURLToPath } from "node:url";
import { pathToFileURL } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const gatePath = path.join(ROOT, "lib/continuity/continuity-quality-gate.ts");
const buildPath = path.join(ROOT, "lib/continuity/build-continuity-lines.ts");

const failures = [];

const gateSrc = await import("node:fs").then((fs) => fs.readFileSync(gatePath, "utf8"));
if (!gateSrc.includes("CONTINUITY_FALLBACK_LINE")) {
  failures.push("continuity-quality-gate missing fallback");
}
if (!gateSrc.includes("isLowQualityTranscript")) {
  failures.push("continuity-quality-gate incomplete");
}

const buildSrc = await import("node:fs").then((fs) => fs.readFileSync(buildPath, "utf8"));
if (!buildSrc.includes("continuity-quality-gate")) {
  failures.push("build-continuity-lines must use continuity-quality-gate");
}

const mod = await import(pathToFileURL(gatePath).href);

const bad = [
  "1, 2, 3, 4, 5",
  "this is just a test",
  "please please please",
  "123",
];
for (const sample of bad) {
  if (!mod.isLowQualityTranscript(sample) && !mod.isLowQualityContinuityQuote(sample)) {
    failures.push(`expected low quality for: ${sample}`);
  }
}

if (mod.gateContinuityLine("You mentioned this again after 9 days.") === null) {
  failures.push("good continuity line should pass gate");
}
if (mod.gateContinuityLine('Earlier: "1, 2, 3" Now: "4, 5, 6"') !== null) {
  failures.push("numeric sequence line should be blocked");
}

if (failures.length > 0) {
  console.error("validate-continuity-quality-gate failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-continuity-quality-gate ok");
