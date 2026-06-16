#!/usr/bin/env node
/**
 * Archive OS — command center reputation-first layout and trust surfaces.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

const commandCenter = read("components/archive/ArchiveCommandCenter.tsx");
for (const token of ["ArchiveReputationCard", "WhyTheArchiveTrustsThis", "ArchiveMeaningSummary"]) {
  if (!commandCenter.includes(token)) fail(`Archive OS command center missing ${token}`);
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:archive-os"]) {
  fail("package.json missing validate:archive-os");
}
if (!pkg.scripts?.["validate:archive-reputation"]) {
  fail("package.json missing validate:archive-reputation");
}

if (failures.length) {
  console.error("validate-archive-os failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-archive-os ok");
