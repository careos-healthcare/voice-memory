import type { ProofCheck } from "@/lib/proof/proof-result";
import {
  BILLING_STATUS_PATH,
  DEVICE_SIGNOFF_PATH,
  EMAIL_STATUS_PATH,
  isFreshIsoDate,
  readJsonFile,
  requireTruthy,
  STAGING_STATUS_PATH,
  STRIPE_WEBHOOK_STATUS_PATH,
} from "@/lib/proof/signoff-files";

export function validateStagingProofStatusFile(): ProofCheck[] {
  const file = readJsonFile(STAGING_STATUS_PATH);
  const checks: ProofCheck[] = [];
  if (!file) {
    checks.push({
      name: "staging_proof_status.json",
      status: "blocked",
      detail: "Missing — copy from staging_proof_status.template.json",
    });
    return checks;
  }
  const missing = requireTruthy(file, [
    "databaseReachable",
    "migrationsOk",
    "rateLimiterDurable",
    "stripePriceLookup",
    "httpsAppUrl",
    "healthOk",
  ]);
  if (!isFreshIsoDate(file.verifiedAt)) missing.push("verifiedAt stale or missing");
  if (typeof file.verifiedBy !== "string" || !String(file.verifiedBy).trim()) {
    missing.push("verifiedBy required");
  }
  checks.push({
    name: "staging_proof_status.json",
    status: missing.length ? "blocked" : "pass",
    detail: missing.length ? missing.join("; ") : "Fresh staging sign-off.",
  });
  return checks;
}

export function validateBillingProofStatusFile(): ProofCheck[] {
  const stripe = readJsonFile(STRIPE_WEBHOOK_STATUS_PATH);
  const billing = readJsonFile(BILLING_STATUS_PATH);
  const file = stripe ?? billing;
  const checks: ProofCheck[] = [];
  if (!file) {
    checks.push({
      name: "stripe_webhook_proof_status.json",
      status: "blocked",
      detail: "Missing stripe_webhook_proof_status.json or live_billing_proof_status.json",
    });
    return checks;
  }
  const keys = stripe
    ? [
        "checkoutSessionCompleted",
        "customerSubscriptionCreated",
        "customerSubscriptionUpdated",
        "customerSubscriptionDeleted",
        "invoicePaymentFailed",
        "duplicateWebhookReplay",
        "stripeWebhookVerified",
      ]
    : ["stripeWebhookVerified", "stripeCheckoutVerified"];
  const missing = requireTruthy(file, keys);
  if (!isFreshIsoDate(file.verifiedAt)) missing.push("verifiedAt stale or missing");
  checks.push({
    name: "stripe/billing proof status",
    status: missing.length ? "blocked" : "pass",
    detail: missing.length ? missing.join("; ") : "Fresh billing/webhook sign-off.",
  });
  return checks;
}

export function validateEmailProofStatusFile(): ProofCheck[] {
  const file = readJsonFile(EMAIL_STATUS_PATH);
  if (!file) {
    return [
      {
        name: "email_delivery_proof_status.json",
        status: "blocked",
        detail: "Missing — required when email enabled for launch",
      },
    ];
  }
  const missing = requireTruthy(file, ["deliveryVerified"]);
  if (!isFreshIsoDate(file.verifiedAt)) missing.push("verifiedAt stale");
  return [
    {
      name: "email_delivery_proof_status.json",
      status: missing.length ? "blocked" : "pass",
      detail: missing.length ? missing.join("; ") : "Fresh email delivery sign-off.",
    },
  ];
}

export function validateDeviceProofSignoff(): ProofCheck[] {
  const file = readJsonFile(DEVICE_SIGNOFF_PATH);
  if (!file) {
    return [
      {
        name: "device_proof_signoff.json",
        status: "blocked",
        detail: "Missing — complete real device checklist first",
      },
    ];
  }
  const boolKeys = [
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
  const missing = requireTruthy(file, boolKeys);
  for (const key of ["testerName", "date", "deviceMatrix", "environment"]) {
    if (!file[key] || String(file[key]).trim().length === 0) {
      missing.push(`${key} required`);
    }
  }
  const ts = Date.parse(String(file.date ?? ""));
  if (!Number.isFinite(ts)) missing.push("date invalid");
  else if (Date.now() - ts > 30 * 24 * 60 * 60 * 1000) {
    missing.push("sign-off older than 30 days");
  }
  return [
    {
      name: "device_proof_signoff.json",
      status: missing.length ? "blocked" : "pass",
      detail: missing.length ? missing.join("; ") : `Signed by ${file.testerName}`,
    },
  ];
}
