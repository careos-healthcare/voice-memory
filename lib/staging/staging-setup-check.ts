import { existsSync } from "node:fs";

import { isStripeConfigured } from "@/lib/billing/stripe-config";
import type { ProofCheck } from "@/lib/proof/proof-result";
import { formatProofChecks } from "@/lib/proof/proof-result";
import {
  DEVICE_SIGNOFF_PATH,
  EMAIL_STATUS_PATH,
  STAGING_STATUS_PATH,
  STRIPE_WEBHOOK_STATUS_PATH,
} from "@/lib/proof/signoff-files";
import {
  validateBillingProofStatusFile,
  validateDeviceProofSignoff,
  validateEmailProofStatusFile,
  validateStagingProofStatusFile,
} from "@/lib/proof/signoff-validation";
import { getEmailMode, isEmailDisabled } from "@/lib/server/email-mode";
import { isAuthSecretStrong, isDebugTokenStrong } from "@/lib/server/production-env";

export type StagingSetupVerdict = "PASS" | "BLOCKED" | "FAIL";

export interface StagingSetupReport {
  verdict: StagingSetupVerdict;
  checks: ProofCheck[];
  missing: string[];
}

function envPresent(name: string): boolean {
  return Boolean(process.env[name]?.trim());
}

export function runStagingSetupCheck(): StagingSetupReport {
  const checks: ProofCheck[] = [];
  const add = (name: string, status: ProofCheck["status"], detail: string) => {
    checks.push({ name, status, detail });
  };

  if (envPresent("DATABASE_URL")) {
    add("DATABASE_URL", "pass", "Set (value not logged).");
  } else {
    add("DATABASE_URL", "blocked", "Missing on host.");
  }

  if (isAuthSecretStrong(process.env.AUTH_SECRET)) {
    add("AUTH_SECRET", "pass", "Strong (length/format OK; not logged).");
  } else if (!process.env.AUTH_SECRET?.trim()) {
    add("AUTH_SECRET", "blocked", "Missing.");
  } else {
    add("AUTH_SECRET", "fail", "Present but weak — rotate before staging.");
  }

  if (envPresent("OPENAI_API_KEY")) {
    add("OPENAI_API_KEY", "pass", "Set (not logged).");
  } else {
    add("OPENAI_API_KEY", "blocked", "Missing.");
  }

  const appUrl =
    process.env.NEXT_PUBLIC_APP_URL?.trim() || process.env.APP_URL?.trim() || "";
  if (!appUrl) {
    add("APP_URL_HTTPS", "blocked", "NEXT_PUBLIC_APP_URL or APP_URL missing.");
  } else if (!appUrl.startsWith("https://")) {
    add("APP_URL_HTTPS", "fail", "App URL must be HTTPS on staging.");
  } else {
    add("APP_URL_HTTPS", "pass", "HTTPS app URL configured (host not logged).");
  }

  if (isStripeConfigured()) {
    add("STRIPE_ENV", "pass", "STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, STRIPE_PRO_PRICE_ID present.");
  } else {
    add("STRIPE_ENV", "blocked", "Stripe env incomplete.");
  }

  if (process.env.STRIPE_WEBHOOK_LIVE_PROOF === "1") {
    add("STRIPE_WEBHOOK_LIVE_PROOF", "pass", "Host attestation set (after manual webhook proof).");
  } else {
    add(
      "STRIPE_WEBHOOK_LIVE_PROOF",
      "blocked",
      "Set to 1 on host only after stripe_webhook_proof_status.json is complete.",
    );
  }

  if (isEmailDisabled()) {
    add("EMAIL_MODE", "pass", "EMAIL_DISABLED=true.");
  } else if (getEmailMode() === "resend") {
    add("EMAIL_MODE", "pass", "Resend configured (RESEND_API_KEY + EMAIL_FROM; not logged).");
  } else {
    add("EMAIL_MODE", "blocked", "Set EMAIL_DISABLED=true or configure Resend.");
  }

  const debug = process.env.DEBUG_ACCESS_TOKEN?.trim();
  if (!debug) {
    add("DEBUG_ACCESS_TOKEN", "pass", "Unset (recommended).");
  } else if (isDebugTokenStrong(debug)) {
    add("DEBUG_ACCESS_TOKEN", "pass", "Strong (not logged).");
  } else {
    add("DEBUG_ACCESS_TOKEN", "fail", "Weak DEBUG_ACCESS_TOKEN — unset or rotate.");
  }

  if (process.env.VOICEMEMORY_STAGING_PROOF === "1") {
    add("VOICEMEMORY_STAGING_PROOF", "pass", "Staging proof mode enabled.");
  } else {
    add("VOICEMEMORY_STAGING_PROOF", "blocked", "Set VOICEMEMORY_STAGING_PROOF=1 on staging host.");
  }

  if (process.env.VOICEMEMORY_DEVICE_PROOF_REQUIRED === "1") {
    add("VOICEMEMORY_DEVICE_PROOF_REQUIRED", "pass", "Device proof enforcement enabled.");
  } else {
    add(
      "VOICEMEMORY_DEVICE_PROOF_REQUIRED",
      "blocked",
      "Set VOICEMEMORY_DEVICE_PROOF_REQUIRED=1 for staging:run-proof / validate:aplus.",
    );
  }

  const signoffPaths = [
    ["staging_proof_status.json", STAGING_STATUS_PATH],
    ["stripe_webhook_proof_status.json", STRIPE_WEBHOOK_STATUS_PATH],
    ["email_delivery_proof_status.json", EMAIL_STATUS_PATH],
    ["device_proof_signoff.json", DEVICE_SIGNOFF_PATH],
  ] as const;

  for (const [label, path] of signoffPaths) {
    add(
      `FILE_${label}`,
      existsSync(path) ? "pass" : "blocked",
      existsSync(path) ? `Found at ${path}` : `Missing — create stub at ${path}`,
    );
  }

  checks.push(...validateStagingProofStatusFile());
  checks.push(...validateBillingProofStatusFile());
  if (!isEmailDisabled()) {
    checks.push(...validateEmailProofStatusFile());
  }
  checks.push(...validateDeviceProofSignoff());

  const missing = checks
    .filter((c) => c.status === "blocked")
    .map((c) => `${c.name}: ${c.detail}`);

  let verdict: StagingSetupVerdict = "PASS";
  if (checks.some((c) => c.status === "fail")) verdict = "FAIL";
  else if (checks.some((c) => c.status === "blocked")) verdict = "BLOCKED";

  return { verdict, checks, missing };
}

export function printStagingSetupCheck(report: StagingSetupReport): void {
  console.log(`\n=== staging:setup-check — ${report.verdict} ===\n`);
  formatProofChecks(report.checks);
  if (report.missing.length) {
    console.log("\nMissing / blocked items:");
    for (const m of report.missing) console.log(`  - ${m}`);
  }
  console.log("");
}
