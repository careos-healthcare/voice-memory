#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const failures = [];
const fail = (msg) => failures.push(msg);

for (const rel of [
  "packages/shared/types/archive-maturity.ts",
  "packages/shared/lib/archive/archive-maturity.ts",
  "packages/shared/lib/archive/archive-maturity-copy.ts",
  "packages/shared/lib/metrics/archive-maturity-events.ts",
  "apps/web/components/archive/ArchiveProgressBar.tsx",
  "packages/shared/lib/archive/archive-maturity-engine.ts",
]) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const copy = fs.readFileSync(path.join(ROOT, "packages/shared/lib/archive/archive-maturity-copy.ts"), "utf8");
for (const stage of [
  "Starting",
  "Building evidence",
  "Beliefs forming",
  "Beliefs changing",
  "Mature archive",
  "More evidence makes beliefs easier to challenge",
]) {
  if (!copy.includes(stage)) fail(`copy missing stage/line: ${stage}`);
}

const progressBar = fs.readFileSync(path.join(ROOT, "apps/web/components/archive/ArchiveProgressBar.tsx"), "utf8");
if (!progressBar.includes("trackArchiveMaturitySeen")) fail("must track seen");
if (!fs.readFileSync(path.join(ROOT, "packages/shared/lib/archive/archive-maturity-engine.ts"), "utf8").includes("ArchiveMaturityEngine")) {
  fail("missing ArchiveMaturityEngine");
}

const events = fs.readFileSync(path.join(ROOT, "packages/shared/lib/metrics/archive-maturity-events.ts"), "utf8");
for (const name of ["archive_maturity_seen", "archive_maturity_clicked"]) {
  if (!events.includes(name)) fail(`event missing: ${name}`);
}

for (const rel of [
  "apps/web/app/page.tsx",
  "apps/web/app/memory/page.tsx",
  "apps/web/app/discover/page.tsx",
  "apps/web/components/Recorder.tsx",
  "apps/web/app/pricing/PricingPageClient.tsx",
]) {
  if (
    !fs.readFileSync(path.join(ROOT, rel), "utf8").includes("ArchiveProgressBar") &&
    !fs.readFileSync(path.join(ROOT, rel), "utf8").includes("ArchiveMaturityMeter")
  ) {
    fail(`${rel} must render ArchiveProgressBar`);
  }
}

if (failures.length) {
  console.error("validate-archive-maturity failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-archive-maturity ok");
