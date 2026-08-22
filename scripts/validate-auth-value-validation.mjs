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
  "packages/shared/lib/auth/auth-value-validation.ts",
  "packages/shared/types/auth-value-validation.ts",
  "apps/web/components/internal/AuthValueValidationPanel.tsx",
  "apps/web/app/internal/auth-value-validation/page.tsx",
  "docs/AUTH_VALUE_VALIDATION.md",
  "docs/AUTH_VALIDATION_EVIDENCE.md",
  "docs/templates/auth-scenario-2-quote-log.md",
  "e2e/guest-first-auth-validation.spec.ts",
]) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const guestAuth = fs.readFileSync(path.join(ROOT, "packages/shared/lib/auth/guest-first-auth.ts"), "utf8");
if (!guestAuth.includes("auth_prompt_shown") || !guestAuth.includes("auth_verified")) {
  fail("guest-first-auth must define auth_prompt_shown and auth_verified");
}

const modal = fs.readFileSync(path.join(ROOT, "apps/web/components/auth/EmailCodeAuthModal.tsx"), "utf8");
if (!modal.includes("trackAuthVerified")) fail("EmailCodeAuthModal must track auth_verified");

const provider = fs.readFileSync(path.join(ROOT, "apps/web/components/auth/AuthPromptProvider.tsx"), "utf8");
if (!provider.includes("trackAuthPromptShown")) fail("AuthPromptProvider must track auth_prompt_shown");

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts["validate:auth-value-validation"]) {
  fail("package.json missing validate:auth-value-validation");
}

const { runAuthValueValidationTests } = await import(
  "../packages/shared/lib/reliability/auth-value-validation-tests.ts"
);
const { failures: testFailures } = await runAuthValueValidationTests();
if (testFailures.length) {
  fail(`auth-value-validation-tests:\n${testFailures.join("\n")}`);
}

const { buildAuthValueValidationReport, AUTH_VALUE_MANUAL_SCENARIOS } = await import(
  "../packages/shared/lib/auth/auth-value-validation.ts"
);
const report = buildAuthValueValidationReport();
assert.equal(AUTH_VALUE_MANUAL_SCENARIOS.length, 6);
assert.ok(report.mainQuestion.length > 10);

if (failures.length) {
  console.error("validate:auth-value-validation failed:\n" + failures.map((f) => `  - ${f}`).join("\n"));
  process.exit(1);
}

console.log("validate:auth-value-validation OK");
