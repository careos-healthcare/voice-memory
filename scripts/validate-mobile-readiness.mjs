#!/usr/bin/env node
/**
 * Mobile Production Readiness v1
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

function mustExist(rel) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

for (const rel of [
  "types/mobile-production-readiness.ts",
  "lib/mobile/release-evidence.ts",
  "lib/mobile/mobile-production-readiness.ts",
  "components/internal/MobileProductionReadinessPanel.tsx",
  "app/internal/mobile-readiness/page.tsx",
  "mobile/evidence/README.md",
  "scripts/generate-mobile-readiness-report.mjs",
  "apps/voicememory_mobile/pubspec.yaml",
  "lib/mobile/mobile-readiness.ts",
]) {
  mustExist(rel);
}

const evidence = read("lib/mobile/release-evidence.ts");
for (const id of [
  "testflight_uploaded",
  "play_internal_uploaded",
  "ios_purchase_tested",
  "android_purchase_tested",
  "readReleaseEvidenceRecords",
  "collectStructuralEvidenceSignals",
]) {
  if (!evidence.includes(id)) fail(`release-evidence missing ${id}`);
}

const production = read("lib/mobile/mobile-production-readiness.ts");
for (const item of [
  "push_notifications",
  "background_recording",
  "offline_mode",
  "sync_recovery",
  "revenuecat",
  "stripe",
  "restore_purchases",
  "ios_signing",
  "android_signing",
  "testflight",
  "play_store",
]) {
  if (!production.includes(item)) fail(`mobile-production-readiness missing ${item}`);
}

const page = read("app/internal/mobile-readiness/page.tsx");
if (!page.includes("MobileProductionReadinessPanel")) {
  fail("mobile-readiness page must use MobileProductionReadinessPanel");
}
if (!page.includes("buildMobileProductionReadinessReport")) {
  fail("mobile-readiness page must build production report");
}

const panel = read("components/internal/MobileProductionReadinessPanel.tsx");
for (const status of ["FAILING", "PASSING"]) {
  if (!panel.includes(status)) fail(`panel must render ${status}`);
}
if (!read("types/mobile-production-readiness.ts").includes("UNKNOWN")) {
  fail("types must define UNKNOWN status");
}

spawnSync("node", ["--import", "tsx", "scripts/generate-mobile-readiness-report.mjs"], {
  cwd: ROOT,
  stdio: "inherit",
});

if (!fs.existsSync(path.join(ROOT, "docs/MOBILE_READINESS_REPORT.md"))) {
  fail("docs/MOBILE_READINESS_REPORT.md not generated");
}

const reportMd = read("docs/MOBILE_READINESS_REPORT.md");
for (const token of [
  "Product Readiness",
  "Store Readiness",
  "Distribution Readiness",
  "Push notifications",
  "TestFlight",
  "Play Store",
]) {
  if (!reportMd.includes(token)) fail(`report missing ${token}`);
}

try {
  const { buildMobileProductionReadinessReport } = await import(
    path.join(ROOT, "lib/mobile/mobile-production-readiness.ts")
  );
  const report = buildMobileProductionReadinessReport();
  if (report.items.length !== 11) {
    fail(`expected 11 checklist items, got ${report.items.length}`);
  }
  if (report.unknownCount > 0) {
    fail(
      `${report.unknownCount} readiness item(s) still UNKNOWN — add evidence or structural FAILING notes`,
    );
    for (const item of report.items.filter((i) => i.status === "UNKNOWN")) {
      fail(`  UNKNOWN: ${item.id}`);
    }
  }
} catch (e) {
  fail(`report import failed: ${e.message}`);
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:mobile-readiness"]) {
  fail("package.json missing validate:mobile-readiness");
}
if (!pkg.scripts?.["generate:mobile-readiness-report"]) {
  fail("package.json missing generate:mobile-readiness-report");
}

if (failures.length) {
  console.error("validate-mobile-readiness failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-mobile-readiness ok");
