#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

for (const rel of [
  "lib/archive/effort-compounds.ts",
  "lib/archive/effort-compounds-copy.ts",
  "lib/metrics/effort-compounds-events.ts",
  "components/archive/EffortCompoundsPanel.tsx",
]) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const copy = fs.readFileSync(path.join(ROOT, "lib/archive/effort-compounds-copy.ts"), "utf8");
for (const phrase of [
  "harder to fool",
  "comparison point",
  "Pro keeps the compounding archive alive",
]) {
  if (!copy.includes(phrase)) fail(`copy missing: ${phrase}`);
}

const paywall = fs.readFileSync(
  path.join(ROOT, "lib/billing/value-moment-paywall-copy.ts"),
  "utf8",
);
if (!paywall.includes("Pro keeps the compounding archive alive")) {
  fail("paywall copy must mention compounding archive");
}

const panel = fs.readFileSync(path.join(ROOT, "components/archive/EffortCompoundsPanel.tsx"), "utf8");
if (!panel.includes("trackEffortCompoundsSeen")) fail("must track effort_compounds_seen");

if (failures.length) {
  console.error("validate-effort-compounds failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-effort-compounds ok");
