#!/usr/bin/env node
/**
 * Offline Sync Production Verification v1 — validate:offline-sync-production
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
  "packages/shared/types/offline-sync-production-verification.ts",
  "packages/shared/lib/mobile/offline-sync-production-verification.ts",
  "mobile/evidence/offline_sync_tested.json",
  "apps/mobile/lib/features/offline_sync/archive_integrity_snapshot.dart",
  "apps/mobile/lib/features/offline_sync/offline_sync_journey_store.dart",
  "apps/mobile/lib/features/offline_sync/offline_sync_production_evidence.dart",
  "apps/mobile/lib/features/sync/screens/offline_sync_verification_screen.dart",
  "apps/mobile/lib/services/sync_service.dart",
]) {
  mustExist(rel);
}

const router = read("apps/mobile/lib/router/app_router.dart");
if (!router.includes("/offline-sync-verify")) {
  fail("app_router must register /offline-sync-verify");
}

const screen = read("apps/mobile/lib/features/sync/screens/offline_sync_verification_screen.dart");
if (screen.includes("simulator") && !screen.includes("Physical device")) {
  fail("screen must warn physical device only");
}
if (screen.includes("FlutterLocalNotifications")) {
  fail("offline sync must not use local notifications");
}

const lib = read("packages/shared/lib/mobile/offline-sync-production-verification.ts");
for (const token of [
  "offline_sync_tested.json",
  "belief_preserved",
  "evidence_preserved",
  "reflections_recorded_offline",
  "reflections_synced",
  "isOfflineSyncProductionPassing",
]) {
  if (!lib.includes(token)) fail(`offline-sync-production-verification missing ${token}`);
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:offline-sync-production"]) {
  fail("package.json missing validate:offline-sync-production");
}

try {
  const {
    readOfflineSyncEvidence,
    isOfflineSyncProductionPassing,
    buildOfflineSyncProductionReport,
  } = await import(path.join(ROOT, "packages/shared/lib/mobile/offline-sync-production-verification.ts"));

  const evidence = readOfflineSyncEvidence();
  if (!evidence) {
    fail("missing offline_sync_tested.json");
  } else {
    for (const field of [
      "success",
      "device",
      "platform",
      "reflections_recorded_offline",
      "reflections_synced",
      "belief_preserved",
      "evidence_preserved",
      "timestamp",
    ]) {
      if (!(field in evidence)) fail(`offline_sync_tested.json missing field: ${field}`);
    }
    if (evidence.success !== true) {
      fail("success must be true after physical device offline sync test");
    }
    if (evidence.belief_preserved !== true) {
      fail("belief_preserved must be true");
    }
    if (evidence.evidence_preserved !== true) {
      fail("evidence_preserved must be true");
    }
    if (evidence.reflections_recorded_offline === 0) {
      fail("reflections_recorded_offline must be > 0");
    }
    if (evidence.reflections_recorded_offline !== evidence.reflections_synced) {
      fail(
        `reflections_recorded_offline (${evidence.reflections_recorded_offline}) must equal reflections_synced (${evidence.reflections_synced})`,
      );
    }
    if (!evidence.timestamp) fail("timestamp required");
    if (!evidence.platform) fail("platform required");
    if (!evidence.device) fail("device required");
    if (evidence.device.includes("simulator") || evidence.device.includes("emulator")) {
      fail("device must be physical — not simulator or emulator");
    }

    if (!isOfflineSyncProductionPassing(evidence)) {
      fail("isOfflineSyncProductionPassing returned false");
    }

    const report = buildOfflineSyncProductionReport();
    if (report.status !== "PASSING") {
      fail(`offline sync status ${report.status}, expected PASSING`);
    }
  }
} catch (e) {
  fail(`import failed: ${e.message}`);
}

if (failures.length) {
  console.error("validate-offline-sync-production failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-offline-sync-production ok");
