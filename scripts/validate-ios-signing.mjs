#!/usr/bin/env node
/**
 * Store Distribution Verification v1 — validate:ios-signing
 * Fails unless ios_signing_tested.json proves archive build + App Store Connect upload.
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
  "mobile/evidence/ios_signing_tested.json",
]) {
  mustExist(rel);
}

const lib = read("packages/shared/lib/mobile/store-distribution-verification.ts");
for (const token of [
  "ios_signing_tested.json",
  "isIosSigningPassing",
  "iosSigningMissingRequirements",
]) {
  if (!lib.includes(token)) fail(`store-distribution-verification missing ${token}`);
}

const commercial = read("packages/shared/lib/mobile/commercial-evidence.ts");
if (!commercial.includes("isIosSigningPassing")) {
  fail("commercial-evidence must delegate ios_signing_tested to isIosSigningPassing");
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:ios-signing"]) {
  fail("package.json missing validate:ios-signing");
}

try {
  const {
    readIosSigningEvidence,
    isIosSigningPassing,
    iosSigningMissingRequirements,
  } = await import(path.join(ROOT, "packages/shared/lib/mobile/store-distribution-verification.ts"));

  const evidence = readIosSigningEvidence();
  if (!evidence) {
    fail("missing or unreadable ios_signing_tested.json");
  } else {
    for (const field of [
      "success",
      "archive_build_created",
      "uploaded_to_app_store_connect",
      "timestamp",
    ]) {
      if (!(field in evidence)) {
        fail(`ios_signing_tested.json missing field: ${field}`);
      }
    }

    const missing = iosSigningMissingRequirements(evidence);
    for (const m of missing) {
      fail(`ios signing incomplete: ${m}`);
    }

    if (!isIosSigningPassing(evidence)) {
      fail("isIosSigningPassing returned false");
    }
  }
} catch (e) {
  fail(`import failed: ${e.message}`);
}

if (failures.length) {
  console.error("validate:ios-signing failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate:ios-signing ok");
