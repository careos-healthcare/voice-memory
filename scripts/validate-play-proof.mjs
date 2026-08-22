#!/usr/bin/env node
/**
 * Store Distribution Verification v1 — validate:play-proof
 * Fails unless play_internal_tested.json proves upload, install, journey, purchase, restore.
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
  "packages/shared/types/store-distribution-verification.ts",
  "packages/shared/lib/mobile/store-distribution-verification.ts",
  "mobile/evidence/play_internal_tested.json",
  "apps/web/components/internal/StoreReadinessPanel.tsx",
  "apps/web/app/internal/store-readiness/page.tsx",
]) {
  mustExist(rel);
}

const lib = read("packages/shared/lib/mobile/store-distribution-verification.ts");
for (const token of [
  "play_internal_tested.json",
  "isPlayProofPassing",
  "playProofMissingRequirements",
]) {
  if (!lib.includes(token)) fail(`store-distribution-verification missing ${token}`);
}

const commercial = read("packages/shared/lib/mobile/commercial-evidence.ts");
if (!commercial.includes("isPlayProofPassing")) {
  fail("commercial-evidence must delegate play_internal_tested to isPlayProofPassing");
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:play-proof"]) {
  fail("package.json missing validate:play-proof");
}

try {
  const {
    readPlayInternalEvidence,
    isPlayProofPassing,
    playProofMissingRequirements,
  } = await import(path.join(ROOT, "packages/shared/lib/mobile/store-distribution-verification.ts"));

  const evidence = readPlayInternalEvidence();
  if (!evidence) {
    fail("missing or unreadable play_internal_tested.json");
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
        fail(`play_internal_tested.json missing field: ${field}`);
      }
    }

    const missing = playProofMissingRequirements(evidence);
    for (const m of missing) {
      fail(`play internal proof incomplete: ${m}`);
    }

    if (!isPlayProofPassing(evidence)) {
      fail("isPlayProofPassing returned false");
    }
  }
} catch (e) {
  fail(`import failed: ${e.message}`);
}

if (failures.length) {
  console.error("validate:play-proof failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate:play-proof ok");
