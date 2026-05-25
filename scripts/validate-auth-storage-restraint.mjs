#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED_FILES = [
  "lib/server/auth-storage.ts",
  "lib/server/auth-store.ts",
  "lib/email/send-auth-code.ts",
  "app/api/auth/send-code/route.ts",
];

const missing = REQUIRED_FILES.filter((rel) => !fs.existsSync(path.join(ROOT, rel)));
if (missing.length > 0) {
  console.error("Auth storage validation failed — missing files:\n");
  for (const file of missing) console.error(`  ${file}`);
  process.exit(1);
}

const authStorage = fs.readFileSync(path.join(ROOT, "lib/server/auth-storage.ts"), "utf8");
const authStore = fs.readFileSync(path.join(ROOT, "lib/server/auth-store.ts"), "utf8");
const sendCodeRoute = fs.readFileSync(
  path.join(ROOT, "app/api/auth/send-code/route.ts"),
  "utf8",
);
const sendAuthCode = fs.readFileSync(
  path.join(ROOT, "lib/email/send-auth-code.ts"),
  "utf8",
);
const accountPage = fs.readFileSync(path.join(ROOT, "app/account/page.tsx"), "utf8");
const productionDeploy = fs.readFileSync(
  path.join(ROOT, "docs/PRODUCTION_DEPLOY.md"),
  "utf8",
);

if (!authStorage.includes("memoryBackend") || !authStorage.includes("isProduction()")) {
  console.error("Auth storage validation failed — missing production memory backend.");
  process.exit(1);
}

if (!authStorage.includes("Auth storage is not configured.")) {
  console.error("Auth storage validation failed — missing not-configured message.");
  process.exit(1);
}

if (authStore.includes("ensureDataDir") || authStore.includes("writeJsonFile")) {
  console.error("Auth storage validation failed — auth-store still writes to filesystem directly.");
  process.exit(1);
}

if (sendCodeRoute.includes("ensureDataDir") || sendCodeRoute.includes("writeJsonFile")) {
  console.error("Auth storage validation failed — send-code route must not use filesystem.");
  process.exit(1);
}

if (sendCodeRoute.includes("devCode") && !sendCodeRoute.includes('process.env.NODE_ENV !== "production"')) {
  console.error("Auth storage validation failed — devCode must be gated to non-production.");
  process.exit(1);
}

if (!sendCodeRoute.includes("sendAuthCodeEmail")) {
  console.error("Auth storage validation failed — send-code route must call sendAuthCodeEmail.");
  process.exit(1);
}

if (!sendAuthCode.includes("RESEND_API_KEY") || !sendAuthCode.includes("EMAIL_FROM")) {
  console.error("Auth storage validation failed — send-auth-code must use Resend env vars.");
  process.exit(1);
}

if (!sendAuthCode.includes("Your VoiceMemory sign-in code")) {
  console.error("Auth storage validation failed — missing auth email subject.");
  process.exit(1);
}

const uiStates = [
  "Sending…",
  "Code sent. Check your email.",
  "Could not send code. Try again.",
  "Could not send the email. Try again in a moment.",
  "Auth storage is not configured.",
];
for (const line of uiStates) {
  if (!accountPage.includes(line)) {
    console.error(`Auth storage validation failed — account page missing UI state: "${line}"`);
    process.exit(1);
  }
}

if (!productionDeploy.toLowerCase().includes("postgres")) {
  console.error("Auth storage validation failed — PRODUCTION_DEPLOY.md must note Postgres requirement.");
  process.exit(1);
}

console.log("Auth storage restraint validation passed.");
