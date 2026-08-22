#!/usr/bin/env node
/**
 * Mobile Commercial Readiness v1 — validate:mobile-primary-product
 * Launch blockers only. Evidence must pass for PRIMARY_PLATFORM.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const MOBILE = path.join(ROOT, "apps/mobile");
const failures = [];
const fail = (msg) => failures.push(msg);

function mustExist(rel) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const evidenceFiles = [
  "ios_signing_tested.json",
  "android_signing_tested.json",
  "testflight_tested.json",
  "play_internal_tested.json",
  "revenuecat_store_tested.json",
  "restore_purchases_tested.json",
  "purchase_journey_tested.json",
  "offline_sync_tested.json",
  "native_push_verification.json",
];

for (const rel of [
  "packages/shared/types/mobile-commercial-readiness.ts",
  "packages/shared/lib/mobile/commercial-evidence.ts",
  "packages/shared/lib/mobile/mobile-primary-platform.ts",
  "apps/mobile/lib/billing/revenuecat_service.dart",
  "apps/mobile/lib/screens/mobile_subscription_screen.dart",
  "apps/mobile/lib/screens/restore_purchases_screen.dart",
  "apps/web/app/internal/apple-store-readiness/page.tsx",
  "apps/web/app/internal/google-play-readiness/page.tsx",
  "apps/web/app/internal/store-readiness/page.tsx",
  "packages/shared/types/store-distribution-verification.ts",
  "packages/shared/lib/mobile/store-distribution-verification.ts",
  "apps/web/components/internal/StoreReadinessPanel.tsx",
  "apps/web/app/internal/revenuecat-verification/page.tsx",
  "apps/web/app/internal/restore-verification/page.tsx",
  "packages/shared/lib/mobile/revenuecat-production-verification.ts",
  "packages/shared/lib/mobile/restore-production-verification.ts",
  "apps/web/components/internal/RevenueCatVerificationPanel.tsx",
  "apps/web/components/internal/CommercialReadinessPanel.tsx",
  "apps/mobile/lib/billing/revenuecat_purchase_journey.dart",
  "apps/mobile/lib/screens/revenuecat_verification_screen.dart",
  "apps/mobile/lib/billing/restore_production_evidence.dart",
  "apps/mobile/lib/screens/restore_production_verification_screen.dart",
  "apps/mobile/lib/push/fcm_service.dart",
  "apps/mobile/lib/push/push_deep_link_handler.dart",
  "packages/shared/lib/push/fcm-admin.ts",
  "apps/api/app/api/internal/send-test-push/route.ts",
  "packages/shared/lib/mobile/offline-sync-production-verification.ts",
  "apps/mobile/lib/screens/offline_sync_verification_screen.dart",
  ...evidenceFiles.map((f) => `mobile/evidence/${f}`),
]) {
  mustExist(rel);
}

const pubspec = fs.readFileSync(path.join(MOBILE, "pubspec.yaml"), "utf8");
if (!pubspec.includes("purchases_flutter")) {
  fail("purchases_flutter missing from pubspec");
}

const pricing = fs.readFileSync(
  path.join(MOBILE, "lib/screens/pricing_screen.dart"),
  "utf8",
);
if (pricing.includes("createCheckoutSession") || pricing.includes("launchUrl")) {
  fail("pricing_screen must not use browser Stripe checkout");
}

const paywall = fs.readFileSync(
  path.join(MOBILE, "lib/widgets/value_moment_paywall.dart"),
  "utf8",
);
if (paywall.includes("createCheckoutSession")) {
  fail("value_moment_paywall must not use browser checkout");
}

function runNestedValidate(script, label) {
  const result = spawnSync("npm", ["run", script], { cwd: ROOT, encoding: "utf8" });
  if (result.status !== 0) {
    fail(`${label} must pass`);
    const out = `${result.stdout}\n${result.stderr}`;
    for (const line of out.split("\n").filter((l) => l.trim().startsWith("-"))) {
      fail(line.trim());
    }
  }
}

runNestedValidate("validate:push-production", "validate:push-production (FCM evidence)");
runNestedValidate("validate:testflight-proof", "validate:testflight-proof");
runNestedValidate("validate:play-proof", "validate:play-proof");
runNestedValidate("validate:ios-signing", "validate:ios-signing");
runNestedValidate("validate:android-signing", "validate:android-signing");

const pubspecPush = fs.readFileSync(path.join(MOBILE, "pubspec.yaml"), "utf8");
if (!pubspecPush.includes("firebase_messaging")) {
  fail("firebase_messaging required — push pillar uses FCM not local notifications");
}

const { buildMobilePrimaryPlatformReport, collectMobilePrimaryProductFailures } =
  await import(path.join(ROOT, "packages/shared/lib/mobile/mobile-primary-platform.ts"));

const report = buildMobilePrimaryPlatformReport();

console.log(`MOBILE_PRIMARY_PLATFORM_VERDICT: ${report.verdict}`);
if (report.reasons.length) {
  console.log("Reasons:");
  for (const r of report.reasons) console.log(`  - ${r}`);
}
console.log(
  `Evidence passing: ${report.evidencePassing.length}/${report.evidencePassing.length + report.evidenceFailing.length}`,
);

for (const f of collectMobilePrimaryProductFailures()) {
  fail(f);
}

const flutter = spawnSync("flutter", ["--version"], { encoding: "utf8" });
if (flutter.status === 0) {
  console.log("Running flutter pub get…");
  spawnSync("flutter", ["pub", "get"], { cwd: MOBILE, encoding: "utf8" });
  console.log("Running flutter analyze…");
  const analyze = spawnSync("flutter", ["analyze"], { cwd: MOBILE, encoding: "utf8" });
  const analyzeOut = `${analyze.stdout}\n${analyze.stderr}`;
  if (/^\s*error\s•/m.test(analyzeOut)) {
    fail(`flutter analyze reported errors:\n${analyzeOut}`);
  }
} else {
  console.warn("Flutter SDK not available — skipping flutter analyze");
}

if (failures.length) {
  console.error("validate:mobile-primary-product failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate:mobile-primary-product ok");
