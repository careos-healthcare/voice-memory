#!/usr/bin/env node
/**
 * Store Distribution Verification v1 — validate:android-signing
 * Fails unless android_signing_tested.json proves signed AAB + Play Console upload.
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
  "mobile/evidence/android_signing_tested.json",
]) {
  mustExist(rel);
}

const lib = read("lib/mobile/store-distribution-verification.ts");
for (const token of [
  "android_signing_tested.json",
  "isAndroidSigningPassing",
  "androidSigningMissingRequirements",
]) {
  if (!lib.includes(token)) fail(`store-distribution-verification missing ${token}`);
}

const commercial = read("lib/mobile/commercial-evidence.ts");
if (!commercial.includes("isAndroidSigningPassing")) {
  fail("commercial-evidence must delegate android_signing_tested to isAndroidSigningPassing");
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:android-signing"]) {
  fail("package.json missing validate:android-signing");
}

try {
  const {
    readAndroidSigningEvidence,
    isAndroidSigningPassing,
    androidSigningMissingRequirements,
  } = await import(path.join(ROOT, "lib/mobile/store-distribution-verification.ts"));

  const evidence = readAndroidSigningEvidence();
  if (!evidence) {
    fail("missing or unreadable android_signing_tested.json");
  } else {
    for (const field of [
      "success",
      "signed_aab_created",
      "uploaded_to_play_console",
      "timestamp",
    ]) {
      if (!(field in evidence)) {
        fail(`android_signing_tested.json missing field: ${field}`);
      }
    }

    const missing = androidSigningMissingRequirements(evidence);
    for (const m of missing) {
      fail(`android signing incomplete: ${m}`);
    }

    if (!isAndroidSigningPassing(evidence)) {
      fail("isAndroidSigningPassing returned false");
    }
  }
} catch (e) {
  fail(`import failed: ${e.message}`);
}

if (failures.length) {
  console.error("validate:android-signing failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate:android-signing ok");
