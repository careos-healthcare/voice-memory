#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const required = [
  "packages/shared/types/return-thread.ts",
  "packages/shared/lib/continuity/return-threads.ts",
  "packages/shared/lib/continuity/build-continuity-lines.ts",
  "apps/web/components/continuity/ReturnThreadCard.tsx",
  "apps/web/components/continuity/ReturnThreadsOverview.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    failures.push(`missing ${rel}`);
  }
}

const threads = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/continuity/return-threads.ts"),
  "utf8",
);
const types = [
  "repeated_phrase",
  "unresolved_problem",
  "recurring_person",
  "contradiction",
  "changed_position",
  "silence_then_return",
  "emotional_reversal",
  "recurring_uncertainty",
];
for (const t of types) {
  if (!threads.includes(`"${t}"`)) failures.push(`return-threads missing type ${t}`);
}
if (!threads.includes("buildReturnThreads") || !threads.includes("groupReturnThreads")) {
  failures.push("return-threads exports incomplete");
}

const lines = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/continuity/build-continuity-lines.ts"),
  "utf8",
);
if (!lines.includes("buildContinuityLineForThread") || !lines.includes("preMicContinuityLine")) {
  failures.push("build-continuity-lines incomplete");
}

const primaryRoutes = [
  "apps/web/app/insights/page.tsx",
  "apps/web/app/timeline/page.tsx",
  "apps/web/app/memory/page.tsx",
];
for (const file of primaryRoutes) {
  const text = fs.readFileSync(path.join(ROOT, file), "utf8");
  if (!text.includes("ReturnThreadsOverview")) {
    failures.push(`${file} must use ReturnThreadsOverview`);
  }
  if (/MemoryTimelineDashboard|PatternsDetectedSection|InsightCard/.test(text)) {
    failures.push(`${file} must not use legacy insight surfaces`);
  }
}

if (failures.length > 0) {
  console.error("validate-return-threads failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-return-threads ok");
