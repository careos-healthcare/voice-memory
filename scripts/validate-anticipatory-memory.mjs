#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const copyPath = path.join(ROOT, "lib/product/anticipatory-memory-copy.ts");
const componentPath = path.join(ROOT, "components/memory/AnticipatoryEmptyState.tsx");

if (!fs.existsSync(copyPath)) failures.push("missing anticipatory-memory-copy.ts");
if (!fs.existsSync(componentPath)) failures.push("missing AnticipatoryEmptyState.tsx");

const copy = fs.readFileSync(copyPath, "utf8");
for (const token of [
  "REFLECTION_MILESTONES",
  "RECORD_CTA_LABEL",
  "REFLECTION_MILESTONES",
  "By three, what repeats may show up",
]) {
  if (!copy.includes(token)) failures.push(`anticipatory copy missing ${token}`);
}

const pages = [
  "app/journal/page.tsx",
  "app/memory/page.tsx",
  "app/insights/page.tsx",
  "app/timeline/page.tsx",
];
for (const rel of pages) {
  const src = fs.readFileSync(path.join(ROOT, rel), "utf8");
  if (!src.includes("AnticipatoryEmptyState")) {
    failures.push(`${rel} must use AnticipatoryEmptyState`);
  }
  if (/No reflections yet|Nothing here yet|Not enough yet to see/i.test(src)) {
    failures.push(`${rel} still uses dead empty headline`);
  }
}

if (failures.length > 0) {
  console.error("validate-anticipatory-memory failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-anticipatory-memory ok");
