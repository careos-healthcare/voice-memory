#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const failures = [];

const quick = fs.readFileSync(path.join(ROOT, "lib/mobile/quick-entry.ts"), "utf8");
if (!quick.includes("buildDirectRecordHref") || !quick.includes("QUICK_ENTRY_PATH")) {
  failures.push("quick-entry must support direct /record href");
}

const start = fs.readFileSync(
  path.join(ROOT, "lib/reflection/start-record-return.ts"),
  "utf8",
);
if (!start.includes("hrefForRecordReturn")) {
  failures.push("start-record-return must export hrefForRecordReturn");
}

for (const rel of [
  "components/clarity/SortThisOutAloudPrompt.tsx",
  "components/open-loops/OpenLoopReturnPrompt.tsx",
]) {
  const text = fs.readFileSync(path.join(ROOT, rel), "utf8");
  if (!text.includes("/record") && !text.includes("buildDirectRecordHref")) {
    failures.push(`${rel} must route to /record without homepage`);
  }
}

const home = fs.readFileSync(path.join(ROOT, "app/page.tsx"), "utf8");
if (!home.includes("hrefForRecordReturn")) {
  failures.push("homepage record-again must support direct /record href");
}

if (failures.length > 0) {
  console.error("validate-homepage-dependency failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-homepage-dependency ok");
