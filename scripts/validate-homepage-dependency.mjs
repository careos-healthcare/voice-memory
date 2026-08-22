#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const failures = [];

const quick = fs.readFileSync(path.join(ROOT, "packages/shared/lib/mobile/quick-entry.ts"), "utf8");
if (!quick.includes("buildDirectRecordHref") || !quick.includes("QUICK_ENTRY_PATH")) {
  failures.push("quick-entry must support direct /record href");
}

const start = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/reflection/start-record-return.ts"),
  "utf8",
);
if (!start.includes("hrefForRecordReturn")) {
  failures.push("start-record-return must export hrefForRecordReturn");
}

const home = fs.readFileSync(path.join(ROOT, "apps/web/app/page.tsx"), "utf8");
if (
  !home.includes("Save the moment. See what returns.") &&
  !home.includes("WEB_MARKETING_PROMISE")
) {
  failures.push("homepage must use approved marketing promise");
}
if (home.includes("Recorder") || home.includes('id="recorder"')) {
  failures.push("homepage must not embed web recorder");
}

if (failures.length > 0) {
  console.error("validate-homepage-dependency failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-homepage-dependency ok");
