#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "packages/shared/lib/clarity/thinking-out-loud-signals.ts",
  "packages/shared/lib/clarity/thought-patterns.ts",
  "packages/shared/lib/clarity/clarity-copy.ts",
  "packages/shared/lib/clarity/clarity-record.ts",
  "packages/shared/lib/clarity/clarity-observation.ts",
  "packages/shared/lib/clarity/clarity-storage.ts",
  "packages/shared/lib/clarity/after-save-clarity.ts",
  "packages/shared/lib/clarity/clarity-resurfacing.ts",
  "apps/web/components/clarity/SortThisOutAloudPrompt.tsx",
  "apps/web/components/clarity/CirclingThoughtsSection.tsx",
];

const BANNED = [
  /\byou should\b/i,
  /\bright or wrong\b/i,
  /\bhealthy response\b/i,
  /\btoxic\b/i,
  /\bnarcissist\b/i,
  /\btherapy\b/i,
  /\bcoach\b/i,
  /\baction plan\b/i,
  /\brecommendation\b/i,
  /\bemotionally responsible response\b/i,
  /\bdiagnose\b/i,
  /\bfix them\b/i,
  /\bresolve the conflict\b/i,
];

const failures = [];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    failures.push(`missing ${rel}`);
  }
}

const scanDirs = ["packages/shared/lib/clarity", "apps/web/components/clarity"];
for (const rel of scanDirs) {
  const dir = path.join(ROOT, rel);
  for (const file of fs.readdirSync(dir)) {
    if (!file.endsWith(".ts") && !file.endsWith(".tsx")) continue;
    const text = fs.readFileSync(path.join(dir, file), "utf8");
    for (const re of BANNED) {
      if (re.test(text)) {
        failures.push(`${rel}/${file}: banned pattern ${re}`);
      }
    }
  }
}

const copy = fs.readFileSync(path.join(ROOT, "packages/shared/lib/clarity/clarity-copy.ts"), "utf8");
for (const phrase of [
  "Sort this out aloud",
  "Record where this is now",
  "Thoughts that kept circling",
]) {
  if (!copy.includes(phrase)) failures.push(`clarity-copy missing: ${phrase}`);
}

const entry = fs.readFileSync(path.join(ROOT, "apps/web/app/entry/[id]/page.tsx"), "utf8");
if (!entry.includes("SortThisOutAloudPrompt")) {
  failures.push("entry page must render SortThisOutAloudPrompt");
}

const recorder = fs.readFileSync(path.join(ROOT, "apps/web/components/Recorder.tsx"), "utf8");
if (!recorder.includes("clarityRecord")) {
  failures.push("Recorder must accept clarityRecord");
}

if (failures.length > 0) {
  console.error("validate-clarity-restraint failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-clarity-restraint ok");
