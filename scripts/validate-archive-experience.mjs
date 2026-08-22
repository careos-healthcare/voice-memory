#!/usr/bin/env node
/**
 * Archive experience — clarity surfaces, discover reframe, case-file home.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

spawnSync("node", ["scripts/validate-archive-clarity-momentum.mjs"], {
  cwd: ROOT,
  stdio: "inherit",
});

const archiveHome = read("apps/web/components/archive/EvidenceArchiveHome.tsx");
if (!archiveHome.includes("ArchiveDetailHub")) {
  fail("archive home must include ArchiveDetailHub");
}

const discover = read("packages/shared/lib/discover/discover-copy.ts");
if (!discover.includes("DISCOVER_PAGE_EYEBROW")) fail("discover-copy must use archive changes eyebrow");

const caseFile = read("packages/shared/lib/archive/archive-case-file-progress.ts");
for (const token of ["Evidence", "Areas", "under review", "strengthened", "challenged"]) {
  if (!caseFile.includes(token) && !read("apps/web/components/archive/ArchiveCaseFileProgress.tsx").includes(token)) {
    fail(`case file progress missing framing: ${token}`);
  }
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts["validate:archive-experience"]) {
  fail("package.json missing validate:archive-experience");
}

if (failures.length) {
  console.error("validate-archive-experience failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-archive-experience passed");
