import { existsSync } from "node:fs";

import {
  DEVICE_SIGNOFF_PATH,
  EMAIL_STATUS_PATH,
  isFreshIsoDate,
  MAX_SIGNOFF_AGE_MS,
  readJsonFile,
  requireTruthy,
  STAGING_STATUS_PATH,
  STRIPE_WEBHOOK_STATUS_PATH,
} from "@/lib/proof/signoff-files";
import { isEmailDisabled } from "@/lib/server/email-mode";
import { runStagingSetupCheck } from "@/lib/staging/staging-setup-check";

export interface SignoffFileReport {
  path: string;
  exists: boolean;
  completed: string[];
  missing: string[];
  stale: string[];
}

const STAGING_KEYS = [
  "databaseReachable",
  "migrationsOk",
  "rateLimiterDurable",
  "stripePriceLookup",
  "httpsAppUrl",
  "healthOk",
];

const STRIPE_KEYS = [
  "checkoutSessionCompleted",
  "customerSubscriptionCreated",
  "customerSubscriptionUpdated",
  "customerSubscriptionDeleted",
  "invoicePaymentFailed",
  "duplicateWebhookReplay",
  "stripeWebhookVerified",
];

const DEVICE_KEYS = [
  "iPhoneSafari",
  "iPhonePWA",
  "AndroidChrome",
  "AndroidPWA",
  "VoiceOver",
  "TalkBack",
  "microphonePermission",
  "recording",
  "export",
  "accountDeletion",
  "authEmail",
  "StripeStagingCheckout",
  "reducedMotion",
  "offlineLocalOnly",
  "resurfacingFeedback",
];

function analyzeFile(
  path: string,
  boolKeys: string[],
  metaKeys: string[] = [],
  dateKey?: string,
): SignoffFileReport {
  const exists = existsSync(path);
  if (!exists) {
    return {
      path,
      exists: false,
      completed: [],
      missing: [...boolKeys, ...metaKeys.map((k) => `${k} (file missing)`)] ,
      stale: [],
    };
  }

  const file = readJsonFile(path);
  const completed = boolKeys.filter((k) => file?.[k] === true);
  const missing = requireTruthy(file, boolKeys);
  for (const key of metaKeys) {
    if (!file?.[key] || String(file[key]).trim().length === 0) {
      missing.push(`${key} empty`);
    }
  }

  const stale: string[] = [];
  const verifiedAt = file?.verifiedAt;
  if (verifiedAt !== undefined && !isFreshIsoDate(verifiedAt)) {
    stale.push("verifiedAt missing or older than 30 days");
  }
  if (dateKey) {
    const ts = Date.parse(String(file?.[dateKey] ?? ""));
    if (!Number.isFinite(ts)) stale.push(`${dateKey} invalid`);
    else if (Date.now() - ts > MAX_SIGNOFF_AGE_MS) {
      stale.push(`${dateKey} older than 30 days`);
    }
  }

  return { path, exists: true, completed, missing, stale };
}

export interface StagingSignoffStatusReport {
  files: SignoffFileReport[];
  setupVerdict: string;
  aplusExitZeroPossible: boolean;
  blockers: string[];
}

export function runStagingSignoffStatus(): StagingSignoffStatusReport {
  const files: SignoffFileReport[] = [
    analyzeFile(STAGING_STATUS_PATH, STAGING_KEYS, ["verifiedBy"], undefined),
    analyzeFile(STRIPE_WEBHOOK_STATUS_PATH, STRIPE_KEYS, ["verifiedBy"], undefined),
  ];

  if (!isEmailDisabled()) {
    const email = analyzeFile(EMAIL_STATUS_PATH, ["deliveryVerified"], ["verifiedBy"]);
    files.push(email);
  }

  files.push(
    analyzeFile(DEVICE_SIGNOFF_PATH, DEVICE_KEYS, ["testerName", "deviceMatrix", "environment"], "date"),
  );

  const setup = runStagingSetupCheck();
  const blockers: string[] = [];

  for (const f of files) {
    if (!f.exists) blockers.push(`Missing file: ${f.path}`);
    if (f.missing.length) blockers.push(`${f.path}: ${f.missing.join(", ")}`);
    if (f.stale.length) blockers.push(`${f.path}: ${f.stale.join(", ")}`);
  }

  if (setup.verdict !== "PASS") {
    blockers.push(`staging:setup-check is ${setup.verdict}`);
  }

  if (process.env.STRIPE_WEBHOOK_LIVE_PROOF !== "1") {
    blockers.push("STRIPE_WEBHOOK_LIVE_PROOF not set to 1 on host");
  }

  const aplusExitZeroPossible =
    setup.verdict === "PASS" &&
    files.every((f) => f.exists && f.missing.length === 0 && f.stale.length === 0) &&
    blockers.length === 0;

  return {
    files,
    setupVerdict: setup.verdict,
    aplusExitZeroPossible,
    blockers,
  };
}

export function printStagingSignoffStatus(report: StagingSignoffStatusReport): void {
  console.log("\n=== staging:signoff-status ===\n");

  for (const f of report.files) {
    console.log(`— ${f.path} —`);
    console.log(`  exists: ${f.exists}`);
    console.log(
      `  completed (${f.completed.length}): ${f.completed.length ? f.completed.join(", ") : "(none)"}`,
    );
    console.log(
      `  missing (${f.missing.length}): ${f.missing.length ? f.missing.join(", ") : "(none)"}`,
    );
    console.log(`  stale: ${f.stale.length ? f.stale.join("; ") : "(none)"}`);
    console.log("");
  }

  console.log(`staging:setup-check verdict: ${report.setupVerdict}`);
  console.log(
    `validate:aplus exit 0 possible on this host: ${report.aplusExitZeroPossible ? "YES (after live validators pass)" : "NO"}`,
  );

  if (!report.aplusExitZeroPossible && report.blockers.length) {
    console.log("\nBlockers:");
    for (const b of report.blockers) console.log(`  - ${b}`);
  }

  console.log(
    "\nNote: signoff-status does not run live DB/Stripe/health checks — use staging:run-proof on staging host.\n",
  );
}
