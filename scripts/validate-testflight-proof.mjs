#!/usr/bin/env node
/**
 * Store Distribution Verification v1 — validate:testflight-proof
 * Fails unless testflight_tested.json proves upload, install, and core journey.
 * When release manifest has storeBilling.livePurchases=false, purchase/restore
 * booleans are not required (smoke-only mode).
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

function readLivePurchasesEnabled() {
  try {
    const manifest = JSON.parse(read("release/focused_beta_status.json"));
    const live = manifest?.capabilities?.storeBilling?.livePurchases;
    return live === true;
  } catch {
    return true;
  }
}

for (const rel of [
  "packages/shared/types/store-distribution-verification.ts",
  "packages/shared/lib/mobile/store-distribution-verification.ts",
  "mobile/evidence/testflight_tested.json",
  "apps/web/components/internal/StoreReadinessPanel.tsx",
  "apps/web/app/internal/store-readiness/page.tsx",
]) {
  mustExist(rel);
}

const lib = read("packages/shared/lib/mobile/store-distribution-verification.ts");
for (const token of [
  "testflight_tested.json",
  "isTestflightProofPassing",
  "isTestflightSmokePassing",
  "buildStoreDistributionReadinessReport",
  "testflightProofMissingRequirements",
  "testflightSmokeMissingRequirements",
]) {
  if (!lib.includes(token)) fail(`store-distribution-verification missing ${token}`);
}

const commercial = read("packages/shared/lib/mobile/commercial-evidence.ts");
if (!commercial.includes("isTestflightProofPassing")) {
  fail("commercial-evidence must delegate testflight_tested to isTestflightProofPassing");
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:testflight-proof"]) {
  fail("package.json missing validate:testflight-proof");
}

const livePurchases = readLivePurchasesEnabled();

try {
  const {
    readTestflightEvidence,
    isTestflightProofPassing,
    isTestflightSmokePassing,
    testflightProofMissingRequirements,
    testflightSmokeMissingRequirements,
  } = await import(path.join(ROOT, "packages/shared/lib/mobile/store-distribution-verification.ts"));

  const evidence = readTestflightEvidence();
  if (!evidence) {
    fail("missing or unreadable testflight_tested.json");
  } else {
    const requiredFields = livePurchases
      ? [
          "success",
          "build_uploaded",
          "build_installed",
          "onboarding_completed",
          "record_completed",
          "archive_viewed",
          "purchase_completed",
          "restore_completed",
          "timestamp",
        ]
      : [
          "success",
          "build_uploaded",
          "build_installed",
          "onboarding_completed",
          "record_completed",
          "archive_viewed",
          "timestamp",
        ];

    for (const field of requiredFields) {
      if (!(field in evidence)) {
        fail(`testflight_tested.json missing field: ${field}`);
      }
    }

    const missing = livePurchases
      ? testflightProofMissingRequirements(evidence)
      : testflightSmokeMissingRequirements(evidence);
    for (const m of missing) {
      fail(`testflight proof incomplete: ${m}`);
    }

    const passing = livePurchases
      ? isTestflightProofPassing(evidence)
      : isTestflightSmokePassing(evidence);
    if (!passing) {
      fail(
        livePurchases
          ? "isTestflightProofPassing returned false"
          : "isTestflightSmokePassing returned false (livePurchases=false — purchase/restore not required)",
      );
    }
  }
} catch (e) {
  fail(`import failed: ${e.message}`);
}

if (failures.length) {
  console.error("validate:testflight-proof failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log(
  livePurchases
    ? "validate:testflight-proof ok"
    : "validate:testflight-proof ok (smoke-only; livePurchases=false)",
);
