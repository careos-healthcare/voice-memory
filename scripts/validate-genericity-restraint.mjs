#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "packages/shared/lib/resurfacing/genericity-filter.ts",
  "packages/shared/lib/resurfacing/evidence-engine.ts",
  "packages/shared/lib/refinement/callback-tuning.ts",
  "packages/shared/lib/revisit/resurfacing-copy.ts",
];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    console.error(`Genericity validation failed — missing ${rel}`);
    process.exit(1);
  }
}

const filter = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/resurfacing/genericity-filter.ts"),
  "utf8",
);
const evidence = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/resurfacing/evidence-engine.ts"),
  "utf8",
);
const tuning = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/refinement/callback-tuning.ts"),
  "utf8",
);
const copy = fs.readFileSync(path.join(ROOT, "packages/shared/lib/revisit/resurfacing-copy.ts"), "utf8");

for (const [file, src, tokens] of [
  ["genericity-filter.ts", filter, ["isGenericResurfacing", "scoreSpecificity", "MIN_RESURFACING_SPECIFICITY", "passesResurfacingGenericityGate"]],
  ["evidence-engine.ts", evidence, ["passesResurfacingGenericityGate", "isGenericResurfacing"]],
  ["callback-tuning.ts", tuning, ["passesResurfacingGenericityGate", "isGenericResurfacing", "scoreSpecificity"]],
  ["resurfacing-copy.ts", copy, ["isGenericResurfacing"]],
]) {
  for (const token of tokens) {
    if (!src.includes(token)) {
      console.error(`Genericity validation failed — ${file} missing ${token}`);
      process.exit(1);
    }
  }
}

const bannedInFilter = [
  "thinking deeply",
  "patterns are emerging",
  "personal growth",
  "you care deeply",
];
for (const phrase of bannedInFilter) {
  if (!filter.includes(phrase)) {
    console.error(`Genericity validation failed — filter must block "${phrase}"`);
    process.exit(1);
  }
}

console.log("Genericity restraint validation passed.");
