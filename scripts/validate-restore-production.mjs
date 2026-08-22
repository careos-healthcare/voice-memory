#!/usr/bin/env node
/**
 * Restore Purchase Production Verification v1 — validate:restore-production
 * Fails unless restore_purchases_tested.json has success=true.
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

function mustExist(rel) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

for (const rel of [
  "packages/shared/types/restore-production-verification.ts",
  "packages/shared/lib/mobile/restore-production-verification.ts",
  "mobile/evidence/restore_purchases_tested.json",
  "apps/web/components/internal/RestoreVerificationPanel.tsx",
  "apps/web/app/internal/restore-verification/page.tsx",
  "apps/mobile/lib/billing/restore_production_evidence.dart",
  "apps/mobile/lib/screens/restore_production_verification_screen.dart",
]) {
  mustExist(rel);
}

const router = read("apps/mobile/lib/router/app_router.dart");
if (!router.includes("/restore-production-verify")) {
  fail("app_router must register /restore-production-verify");
}

const lib = read("packages/shared/lib/mobile/restore-production-verification.ts");
for (const token of [
  "restore_purchases_tested.json",
  "isRestoreProductionPassing",
  "buildRestoreProductionReport",
  "resolveRestoreReadinessStatus",
]) {
  if (!lib.includes(token)) fail(`restore-production-verification missing ${token}`);
}

const production = read("packages/shared/lib/mobile/mobile-production-readiness.ts");
if (!production.includes("resolveRestorePurchasesItem")) {
  fail("mobile-production-readiness must use resolveRestorePurchasesItem");
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:restore-production"]) {
  fail("package.json missing validate:restore-production");
}

try {
  const {
    readRestorePurchasesEvidence,
    isRestoreProductionPassing,
    buildRestoreProductionReport,
  } = await import(path.join(ROOT, "packages/shared/lib/mobile/restore-production-verification.ts"));

  const evidence = readRestorePurchasesEvidence();
  if (!evidence) {
    fail("missing or unreadable restore_purchases_tested.json");
  } else {
    for (const field of ["success", "device", "platform", "timestamp"]) {
      if (!(field in evidence)) {
        fail(`restore_purchases_tested.json missing field: ${field}`);
      }
    }
    if (evidence.success !== true) {
      fail(
        "success must be true — complete purchase → delete app → reinstall → restore on physical device",
      );
    }
    if (!evidence.timestamp) fail("timestamp required");
    if (!evidence.platform) fail("platform required (ios or android)");
    if (!evidence.device) fail("device required");

    if (!isRestoreProductionPassing(evidence)) {
      fail("isRestoreProductionPassing returned false");
    }

    const report = buildRestoreProductionReport();
    if (report.status !== "PASSING") {
      fail(`Restore readiness status is ${report.status}, expected PASSING`);
    }
  }
} catch (e) {
  fail(`import failed: ${e.message}`);
}

if (failures.length) {
  console.error("validate-restore-production failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-restore-production ok");
