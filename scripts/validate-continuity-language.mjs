#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const linesFile = fs.readFileSync(
  path.join(ROOT, "lib/continuity/build-continuity-lines.ts"),
  "utf8",
);

const requiredPhrases = [
  "You mentioned this again",
  "This came back",
  "Earlier:",
  "Now:",
  "still feels unfinished",
  "stopped talking about this",
];

const failures = [];
for (const phrase of requiredPhrases) {
  if (!linesFile.includes(phrase)) {
    failures.push(`build-continuity-lines missing phrase pattern: ${phrase}`);
  }
}

if (failures.length > 0) {
  console.error("validate-continuity-language failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-continuity-language ok");
