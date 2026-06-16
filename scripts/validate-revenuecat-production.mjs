#!/usr/bin/env node
/**
 * RevenueCat Production Verification v1 — validate:revenuecat-production
 * Fails unless revenuecat_store_tested.json proves purchase + entitlement + restore.
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
  "types/revenuecat-production-verification.ts",
  "lib/mobile/revenuecat-production-verification.ts",
  "mobile/evidence/revenuecat_store_tested.json",
  "components/internal/RevenueCatVerificationPanel.tsx",
  "app/internal/revenuecat-verification/page.tsx",
  "apps/voicememory_mobile/lib/billing/revenuecat_purchase_journey.dart",
  "apps/voicememory_mobile/lib/screens/revenuecat_verification_screen.dart",
  "apps/voicememory_mobile/lib/billing/revenuecat_service.dart",
]) {
  mustExist(rel);
}

const pubspec = read("apps/voicememory_mobile/pubspec.yaml");
if (!pubspec.includes("purchases_flutter")) {
  fail("purchases_flutter missing from pubspec");
}

const router = read("apps/voicememory_mobile/lib/router/app_router.dart");
if (!router.includes("/revenuecat-verify")) {
  fail("app_router must register /revenuecat-verify");
}

const lib = read("lib/mobile/revenuecat-production-verification.ts");
for (const token of [
  "revenuecat_store_tested.json",
  "purchase_completed",
  "entitlement_received",
  "restore_completed",
  "isRevenueCatProductionPassing",
  "buildRevenueCatProductionReport",
  "resolveRevenueCatReadinessStatus",
]) {
  if (!lib.includes(token)) fail(`revenuecat-production-verification missing ${token}`);
}

const production = read("lib/mobile/mobile-production-readiness.ts");
if (!production.includes("resolveRevenueCatItem")) {
  fail("mobile-production-readiness must use resolveRevenueCatItem (evidence-only)");
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:revenuecat-production"]) {
  fail("package.json missing validate:revenuecat-production");
}

try {
  const {
    readRevenueCatStoreEvidence,
    isRevenueCatProductionPassing,
    buildRevenueCatProductionReport,
  } = await import(path.join(ROOT, "lib/mobile/revenuecat-production-verification.ts"));

  const evidence = readRevenueCatStoreEvidence();
  if (!evidence) {
    fail("missing or unreadable revenuecat_store_tested.json");
  } else {
    for (const field of [
      "success",
      "device",
      "platform",
      "offering_loaded",
      "purchase_completed",
      "entitlement_received",
      "restore_completed",
      "timestamp",
    ]) {
      if (!(field in evidence)) {
        fail(`revenuecat_store_tested.json missing field: ${field}`);
      }
    }

    if (!evidence.purchase_completed) {
      fail("purchase_completed must be true — complete sandbox purchase on physical device");
    }
    if (!evidence.entitlement_received) {
      fail("entitlement_received must be true — Pro entitlement after purchase");
    }
    if (!evidence.restore_completed) {
      fail("restore_completed must be true — run restore on physical device");
    }
    if (!evidence.success) {
      fail("success must be true when journey is complete");
    }
    if (!evidence.timestamp) {
      fail("timestamp required after device export");
    }
    if (!evidence.platform) {
      fail("platform required (ios or android)");
    }
    if (!evidence.device) {
      fail("device required");
    }

    if (!isRevenueCatProductionPassing(evidence)) {
      fail("isRevenueCatProductionPassing returned false");
    }

    const report = buildRevenueCatProductionReport();
    if (report.status !== "PASSING") {
      fail(`RevenueCat readiness status is ${report.status}, expected PASSING`);
    }
  }
} catch (e) {
  fail(`import failed: ${e.message}`);
}

if (failures.length) {
  console.error("validate-revenuecat-production failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-revenuecat-production ok");
