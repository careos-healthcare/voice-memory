#!/usr/bin/env node
/**
 * Native Mobile Push Verification v1 — physical iOS + Android evidence required.
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
  "packages/shared/lib/mobile/native-push-verification.ts",
  "mobile/evidence/native_push_verification.json",
  "apps/web/components/internal/NativeMobilePushReadinessPanel.tsx",
  "apps/web/app/internal/mobile-push-readiness/page.tsx",
  "apps/mobile/lib/features/native_push/native_push_verification.dart",
  "apps/mobile/lib/features/native_push/native_push_service.dart",
  "apps/mobile/lib/screens/native_push_verification_screen.dart",
]) {
  mustExist(rel);
}

const pubspec = read("apps/mobile/pubspec.yaml");
if (!pubspec.includes("flutter_local_notifications")) {
  fail("Flutter app must include flutter_local_notifications for native verify");
}

const evidencePath = path.join(ROOT, "mobile/evidence/native_push_verification.json");
if (!fs.existsSync(evidencePath)) {
  fail("missing mobile/evidence/native_push_verification.json");
}

const lib = read("packages/shared/lib/mobile/native-push-verification.ts");
for (const token of [
  "native_push_verification.json",
  "permission_granted",
  "notification_received",
  "notification_opened",
  "destinations_verified",
  "buildNativePushReadinessReport",
  "isNativePushFullyVerified",
  "webVerificationExcluded",
]) {
  if (!lib.includes(token)) fail(`native-push-verification missing ${token}`);
}

const production = read("packages/shared/lib/mobile/mobile-production-readiness.ts");
if (!production.includes("resolveNativePushNotificationsItem")) {
  fail("mobile-production-readiness must use native push for push_notifications");
}
if (!production.includes("Web push verification does not count")) {
  fail("push_notifications must exclude web verification");
}

try {
  const {
    buildNativePushReadinessReport,
    readNativePushVerificationEvidence,
  } = await import(path.join(ROOT, "packages/shared/lib/mobile/native-push-verification.ts"));

  const evidence = readNativePushVerificationEvidence();
  if (!evidence) {
    fail("iOS evidence missing — native_push_verification.json unreadable");
    fail("Android evidence missing — native_push_verification.json unreadable");
  } else {
    if (!evidence.ios) fail("iOS evidence missing");
    if (!evidence.android) fail("Android evidence missing");

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
      ]) {
        if (typeof row[field] !== "boolean") {
          fail(`${platform}.${field} must be boolean`);
        }
      }
      if (!Array.isArray(row.destinations_verified)) {
        fail(`${platform}.destinations_verified must be array`);
      }
    }

    const report = buildNativePushReadinessReport();
    if (!report.webVerificationExcluded) {
      fail("report must exclude web verification");
    }

    const iosPass =
      evidence.ios.permission_granted &&
      evidence.ios.notification_received &&
      evidence.ios.notification_opened;
    const androidPass =
      evidence.android.permission_granted &&
      evidence.android.notification_received &&
      evidence.android.notification_opened;

    if (!iosPass) {
      fail(
        "iOS native push not verified — set permission_granted, notification_received, notification_opened on physical iPhone",
      );
    }
    if (!androidPass) {
      fail(
        "Android native push not verified — set permission_granted, notification_received, notification_opened on physical Android device",
      );
    }

    const requiredRoutes = ["/archive-belief", "/discover", "/record"];
    for (const route of requiredRoutes) {
      if (!evidence.ios.destinations_verified.includes(route)) {
        fail(`iOS missing destination evidence for ${route}`);
      }
      if (!evidence.android.destinations_verified.includes(route)) {
        fail(`Android missing destination evidence for ${route}`);
      }
    }

    if (!evidence.timestamp) {
      fail("timestamp required after native verification export");
    }
    if (!evidence.app_version) {
      fail("app_version required in native_push_verification.json");
    }
  }
} catch (e) {
  fail(`import failed: ${e.message}`);
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:native-push-readiness"]) {
  fail("package.json missing validate:native-push-readiness");
}

if (failures.length) {
  console.error("validate-native-push-readiness failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-native-push-readiness ok");
