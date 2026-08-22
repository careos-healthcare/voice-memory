#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const card = fs.readFileSync(
  path.join(ROOT, "apps/web/components/continuity/ReturnThreadCard.tsx"),
  "utf8",
);

const failures = [];
if (!card.includes("Earlier") || !card.includes("Now")) {
  failures.push("ReturnThreadCard must show Earlier / Now quote blocks");
}
if (!card.includes("continuityLine")) {
  failures.push("ReturnThreadCard must surface continuityLine");
}
if (card.includes("reflection.mood") || /\d\/10/.test(card)) {
  failures.push("ReturnThreadCard must not show mood scores");
}

const overview = fs.readFileSync(
  path.join(ROOT, "apps/web/components/continuity/ReturnThreadsOverview.tsx"),
  "utf8",
);
const sections = [
  "Words that returned",
  "Still unresolved",
  "Earlier / now",
  "You came back to this",
];
for (const title of sections) {
  if (!overview.includes(title)) failures.push(`ReturnThreadsOverview missing section: ${title}`);
}

if (failures.length > 0) {
  console.error("validate-quote-first-continuity failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-quote-first-continuity ok");
