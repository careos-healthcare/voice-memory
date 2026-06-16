#!/usr/bin/env node
/**
 * Push Notification Verification v1
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
  "types/push-verification.ts",
  "lib/notifications/push-verification.ts",
  "components/internal/PushVerificationPanel.tsx",
  "components/notifications/PushVerificationBootstrap.tsx",
  "app/internal/push-verification/page.tsx",
]) {
  mustExist(rel);
}

const lib = read("lib/notifications/push-verification.ts");
for (const token of [
  "lastNotificationSent",
  "lastNotificationDelivered",
  "lastNotificationOpened",
  "recordPushPermissionRequested",
  "recordPushNotificationDelivered",
  "sendPushVerificationNotification",
  "buildPushVerificationReport",
  "PUSH_VERIFICATION_STORE_KEY",
]) {
  if (!lib.includes(token)) fail(`push-verification missing ${token}`);
}

for (const check of [
  "permission_requested",
  "permission_granted",
  "notification_delivered",
  "notification_tapped",
  "correct_screen_opened",
]) {
  if (!lib.includes(check)) fail(`push-verification missing check ${check}`);
}

const panel = read("components/internal/PushVerificationPanel.tsx");
if (!panel.includes("Last notification sent")) fail("panel must show last notification sent");
if (!panel.includes("Last notification delivered")) {
  fail("panel must show last notification delivered");
}
if (!panel.includes("Last notification opened")) fail("panel must show last notification opened");
if (!panel.includes("Request permission")) fail("panel must offer permission request");
if (!panel.includes("Send test notification")) fail("panel must offer send test");

const page = read("app/internal/push-verification/page.tsx");
if (!page.includes("PushVerificationPanel")) fail("page must render PushVerificationPanel");

const providers = read("app/providers.tsx");
if (!providers.includes("PushVerificationBootstrap")) {
  fail("providers must mount PushVerificationBootstrap");
}

try {
  const {
    buildPushVerificationReport,
    PUSH_VERIFICATION_CHECK_IDS,
  } = await import(path.join(ROOT, "lib/notifications/push-verification.ts"));
  const report = buildPushVerificationReport();
  if (report.checks.length !== 5) {
    fail(`expected 5 checks, got ${report.checks.length}`);
  }
  if (PUSH_VERIFICATION_CHECK_IDS.length !== 5) {
    fail("PUSH_VERIFICATION_CHECK_IDS must have 5 entries");
  }
  for (const id of PUSH_VERIFICATION_CHECK_IDS) {
    if (!report.checks.some((c) => c.id === id)) {
      fail(`report missing check ${id}`);
    }
  }
  if (!report.store) fail("report must include store");
} catch (e) {
  fail(`import failed: ${e.message}`);
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:push-verification"]) {
  fail("package.json missing validate:push-verification");
}

if (failures.length) {
  console.error("validate-push-verification failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-push-verification ok");
