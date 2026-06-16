#!/usr/bin/env node
/**
 * Store Distribution Verification v1 — validate:testflight-proof
 * Fails unless testflight_tested.json proves upload, install, journey, purchase, restore.
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
  "types/store-distribution-verification.ts",
  "lib/mobile/store-distribution-verification.ts",
  "mobile/evidence/testflight_tested.json",
  "components/internal/StoreReadinessPanel.tsx",
  "app/internal/store-readiness/page.tsx",
]) {
  mustExist(rel);
}

const lib = read("lib/mobile/store-distribution-verification.ts");
for (const token of [
  "testflight_tested.json",
  "isTestflightProofPassing",
  "buildStoreDistributionReadinessReport",
  "testflightProofMissingRequirements",
]) {
  if (!lib.includes(token)) fail(`store-distribution-verification missing ${token}`);
}

const commercial = read("lib/mobile/commercial-evidence.ts");
if (!commercial.includes("isTestflightProofPassing")) {
  fail("commercial-evidence must delegate testflight_tested to isTestflightProofPassing");
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:testflight-proof"]) {
  fail("package.json missing validate:testflight-proof");
}

try {
  const {
    readTestflightEvidence,
    isTestflightProofPassing,
    testflightProofMissingRequirements,
  } = await import(path.join(ROOT, "lib/mobile/store-distribution-verification.ts"));

  const evidence = readTestflightEvidence();
  if (!evidence) {
    fail("missing or unreadable testflight_tested.json");
  } else {
    for (const field of [
      "success",
      "build_uploaded",
      "build_installed",
      "onboarding_completed",
      "record_completed",
      "archive_viewed",
      "purchase_completed",
      "restore_completed",
      "timestamp",
    ]) {
      if (!(field in evidence)) {
        fail(`testflight_tested.json missing field: ${field}`);
      }
    }

    const missing = testflightProofMissingRequirements(evidence);
    for (const m of missing) {
      fail(`testflight proof incomplete: ${m}`);
    }

    if (!isTestflightProofPassing(evidence)) {
      fail("isTestflightProofPassing returned false");
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
console.log("validate:testflight-proof ok");
