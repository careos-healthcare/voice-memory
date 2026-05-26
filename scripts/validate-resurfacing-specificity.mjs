#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCAN = [
  "lib/memory/resurfacing.ts",
  "lib/memory/revisitation.ts",
  "lib/memory/familiarity-resurfacing.ts",
  "lib/revisit/resurfacing-confidence.ts",
  "lib/refinement/knows-me-moments.ts",
];

const FORBIDDEN_LITERALS = [
  "thinking deeply",
  "going through a lot",
  "processing emotions",
  "been reflecting",
  "personal growth",
  "you seem stressed",
  "patterns are emerging",
  "you care deeply",
  "healing journey",
  "growth journey",
  "memory intelligence",
  "emotional architecture",
  "unlock your insights",
  "discover patterns",
];

let failed = false;

for (const rel of SCAN) {
  const filePath = path.join(ROOT, rel);
  if (!fs.existsSync(filePath)) continue;
  const content = fs.readFileSync(filePath, "utf8");
  for (const phrase of FORBIDDEN_LITERALS) {
    if (content.toLowerCase().includes(phrase.toLowerCase())) {
      console.error(`Resurfacing specificity failed — ${rel} contains "${phrase}"`);
      failed = true;
    }
  }
}

const copyPath = path.join(ROOT, "lib/revisit/resurfacing-copy.ts");
const copy = fs.readFileSync(copyPath, "utf8");
if (!copy.includes("isGenericResurfacing")) {
  console.error("Resurfacing specificity failed — resurfacing-copy must use genericity filter.");
  failed = true;
}

const packageJson = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
for (const script of [
  "validate:genericity",
  "validate:homepage-clarity",
  "validate:resurfacing-specificity",
]) {
  if (!packageJson.includes(script)) {
    console.error(`Resurfacing specificity failed — package.json missing ${script}`);
    failed = true;
  }
}

if (failed) process.exit(1);

console.log("Resurfacing specificity validation passed.");
