#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const HEAVY = [
  "buildQuietHomepagePresentation",
  "LivingResurfacingNote",
  "PrimaryCallbackNote",
  "OpenLoopReturnPrompt",
  "CirclingThoughtsSection",
  "quiet-presentation",
];

for (const rel of ["app/record/page.tsx", "components/capture/QuickRecordPage.tsx"]) {
  const text = fs.readFileSync(path.join(ROOT, rel), "utf8");
  for (const token of HEAVY) {
    if (text.includes(token)) failures.push(`${rel} must not import ${token}`);
  }
}

const direct = fs.readFileSync(path.join(ROOT, "lib/capture/direct-record.ts"), "utf8");
if (!direct.includes("buildDirectRecordHref")) {
  failures.push("direct-record must export buildDirectRecordHref");
}

const manifest = fs.readFileSync(path.join(ROOT, "app/manifest.ts"), "utf8");
for (const url of ["/record", "/record?source=reflex", "/record?source=return"]) {
  if (!manifest.includes(url)) failures.push(`manifest shortcuts must include ${url}`);
}

const home = fs.readFileSync(path.join(ROOT, "app/page.tsx"), "utf8");
if (!home.includes("buildDirectRecordHref") && !home.includes("shouldForceDirectMicNextSession")) {
  failures.push("homepage must support force direct mic redirect");
}

if (failures.length > 0) {
  console.error("validate-direct-record-path failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-direct-record-path ok");
