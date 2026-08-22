#!/usr/bin/env node
/**
 * Native Push Production Verification v2 — validate:push-production
 * Fails unless iOS and Android evidence pass (FCM backend, all destinations).
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
  "packages/shared/types/native-push-verification.ts",
  "packages/shared/types/mobile-push.ts",
  "packages/shared/lib/mobile/native-push-verification.ts",
  "packages/shared/lib/push/fcm-admin.ts",
  "packages/shared/lib/push/mobile-push-devices.ts",
  "apps/api/app/api/push/register/route.ts",
  "apps/api/app/api/internal/send-test-push/route.ts",
  "mobile/evidence/native_push_verification.json",
  "apps/mobile/lib/push/fcm_service.dart",
  "apps/mobile/lib/push/push_deep_link_handler.dart",
  "apps/mobile/lib/screens/native_push_verification_screen.dart",
]) {
  mustExist(rel);
}

const pubspec = read("apps/mobile/pubspec.yaml");
if (!pubspec.includes("firebase_messaging")) {
  fail("firebase_messaging required in pubspec — no local notification harness");
}
if (pubspec.includes("flutter_local_notifications")) {
  const screen = read("apps/mobile/lib/screens/native_push_verification_screen.dart");
  if (screen.includes("showVerificationNotification")) {
    fail("native push screen must use backend FCM send, not local notifications");
  }
}

const nativePushService = read("apps/mobile/lib/features/native_push/native_push_service.dart");
if (nativePushService.includes("FlutterLocalNotificationsPlugin")) {
  fail("NativePushService must not use flutter_local_notifications for production verify");
}

const lib = read("packages/shared/lib/mobile/native-push-verification.ts");
for (const token of [
  "archive_destination_verified",
  "discover_destination_verified",
  "record_destination_verified",
  "isPushProductionPassing",
  "fcmProductionOnly",
]) {
  if (!lib.includes(token)) fail(`native-push-verification missing ${token}`);
}

const production = read("packages/shared/lib/mobile/mobile-production-readiness.ts");
if (!production.includes("resolveNativePushNotificationsItem")) {
  fail("mobile-production-readiness must use native push evidence");
}

try {
  const {
    readNativePushVerificationEvidence,
    isPushProductionPassing,
    buildNativePushReadinessReport,
  } = await import(path.join(ROOT, "packages/shared/lib/mobile/native-push-verification.ts"));

  const evidence = readNativePushVerificationEvidence();
  if (!evidence) {
    fail("missing native_push_verification.json");
  } else {
    for (const platform of ["ios", "android"]) {
      const row = evidence[platform];
      if (!row) {
        fail(`${platform} evidence missing`);
        continue;
      }
      for (const field of [
        "permission_granted",
        "notification_received",
        "notification_opened",
        "archive_destination_verified",
        "discover_destination_verified",
        "record_destination_verified",
      ]) {
        if (row[field] !== true) {
          fail(`${platform}.${field} must be true — complete FCM test on physical device`);
        }
      }
      if (!row.timestamp) {
        fail(`${platform}.timestamp required`);
      }
    }

    if (!isPushProductionPassing()) {
      fail("isPushProductionPassing returned false");
    }

    const report = buildNativePushReadinessReport();
    if (report.ios.status !== "PASSING") {
      fail(`iOS push status ${report.ios.status}, expected PASSING`);
    }
    if (report.android.status !== "PASSING") {
      fail(`Android push status ${report.android.status}, expected PASSING`);
    }
    if (!report.fcmProductionOnly) {
      fail("report must require FCM production verification");
    }
  }
} catch (e) {
  fail(`import failed: ${e.message}`);
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.dependencies?.["firebase-admin"] && !pkg.devDependencies?.["firebase-admin"]) {
  fail("firebase-admin dependency required for backend FCM");
}
if (!pkg.scripts?.["validate:push-production"]) {
  fail("package.json missing validate:push-production");
}

if (failures.length) {
  console.error("validate-push-production failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-push-production ok");
