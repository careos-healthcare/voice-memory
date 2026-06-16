#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const guarded = [
  "app/api/transcribe/route.ts",
  "app/api/analyze/route.ts",
  "app/api/atmosphere/route.ts",
  "app/api/capture/attest/route.ts",
];

for (const rel of guarded) {
  const text = fs.readFileSync(path.join(ROOT, rel), "utf8");
  if (!text.includes("guardOpenAiRoute") && !text.includes("guardAttestRoute")) {
    failures.push(`${rel} missing API guard`);
  }
}

const accountDel = fs.readFileSync(path.join(ROOT, "lib/server/account-deletion.ts"), "utf8");
const deletionChecks = [
  ["sync_blobs", /sync_blobs/],
  ["sessions", /sessions/],
  ["journal_entries", /journal_entries|deleteAllServerJournalEntries/],
  ["billing_entitlements", /billing_entitlements|deleteServerBilling/],
  ["resurfacing_events", /resurfacing_events/],
  ["api_usage", /api_usage/],
  ["openai_daily_spend", /openai_daily_spend/],
];
for (const [label, re] of deletionChecks) {
  if (!re.test(accountDel)) failures.push(`account-deletion missing ${label}`);
}

if (!fs.existsSync(path.join(ROOT, "lib/server/webhook-idempotency.ts"))) {
  failures.push("missing webhook idempotency");
}

const capture = fs.readFileSync(path.join(ROOT, "lib/capture/capture-token.ts"), "utf8");
if (!capture.includes("ipHash")) failures.push("capture token missing IP binding");

const middleware = fs.readFileSync(path.join(ROOT, "middleware.ts"), "utf8");
if (!middleware.includes("isDeprecatedDebugPath")) failures.push("middleware must retire /debug");
if (!middleware.includes("/internal")) failures.push("middleware must guard /internal");

if (failures.length) {
  console.error("validate-security-aplus failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-security-aplus ok");
