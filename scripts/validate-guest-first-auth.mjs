#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

function fail(msg) {
  failures.push(msg);
}

for (const rel of [
  "packages/shared/lib/auth/guest-first-auth.ts",
  "packages/shared/lib/auth/auth-trigger-rules.ts",
  "packages/shared/lib/auth/auth-value-validation.ts",
  "packages/shared/types/auth-trigger.ts",
  "packages/shared/types/auth-value-validation.ts",
  "docs/AUTH_VALUE_VALIDATION.md",
  "apps/web/components/auth/EmailCodeAuthModal.tsx",
  "apps/web/components/auth/ProtectArchiveBanner.tsx",
  "apps/web/components/auth/AuthPromptProvider.tsx",
  "apps/web/components/internal/AuthValueValidationPanel.tsx",
  "apps/web/app/internal/auth-value-validation/page.tsx",
  "apps/mobile/lib/auth/guest_first_auth.dart",
  "apps/mobile/lib/widgets/protect_archive_banner.dart",
]) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const providers = fs.readFileSync(path.join(ROOT, "apps/web/app/providers.tsx"), "utf8");
if (!providers.includes("AuthPromptProvider")) {
  fail("AppProviders must wrap AuthPromptProvider");
}

const page = fs.readFileSync(path.join(ROOT, "apps/web/app/page.tsx"), "utf8");
if (!page.includes("ProtectArchiveBanner")) fail("home must show ProtectArchiveBanner");

const recorder = fs.readFileSync(path.join(ROOT, "apps/web/components/Recorder.tsx"), "utf8");
if (!recorder.includes("ensureCaptureAttested")) {
  fail("Recorder must still use device attest for guest recording");
}

const {
  shouldPromptForAuthTrigger,
  readAuthTriggerContext,
} = await import("../packages/shared/lib/auth/auth-trigger-rules.ts");
const { shouldShowProtectArchiveBanner } = await import("../packages/shared/lib/auth/guest-first-auth.ts");

assert.equal(
  shouldPromptForAuthTrigger("export", { isSignedIn: false, reflectionCount: 0 }),
  false,
);
assert.equal(
  shouldPromptForAuthTrigger("export", { isSignedIn: false, reflectionCount: 2 }),
  true,
);

const guestAuth = fs.readFileSync(path.join(ROOT, "packages/shared/lib/auth/guest-first-auth.ts"), "utf8");
for (const event of [
  "guest_mode_started",
  "protect_archive_clicked",
  "auth_prompt_shown",
  "auth_verified",
]) {
  if (!guestAuth.includes(event)) fail(`guest-first-auth must track ${event}`);
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts["validate:guest-first-auth"]) {
  fail("package.json missing validate:guest-first-auth");
}
if (!pkg.scripts["validate:auth-value-validation"]) {
  fail("package.json missing validate:auth-value-validation");
}

if (failures.length) {
  console.error("validate:guest-first-auth failed:\n" + failures.map((f) => `  - ${f}`).join("\n"));
  process.exit(1);
}

console.log("validate:guest-first-auth OK");
