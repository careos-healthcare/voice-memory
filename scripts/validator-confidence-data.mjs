/**
 * Validator confidence inventory — score 1–5 per validator.
 * High-risk >= 4 when E2E/runtime possible; medium-risk >= 3.
 */

/** @typedef {{ id: string, npm?: string, risk: 'high'|'medium'|'low', score: number, proof: string, counterpart?: string, staticOnly?: boolean }} ValidatorEntry */

export const HIGH_RISK_MIN_SCORE = 4;
export const MEDIUM_RISK_MIN_SCORE = 3;

/** Explicit low-risk static-only validators (acceptable). */
export const STATIC_ONLY_LOW_RISK = [
  "quiet-copy",
  "product-restraint",
  "ux-copy",
  "human-memory-copy",
  "homepage-clarity",
  "wcag-launch-surface-static",
];

/** @type {ValidatorEntry[]} */
export const VALIDATOR_INVENTORY = [
  {
    id: "api-guard",
    npm: "validate:api-guard",
    risk: "high",
    score: 4,
    proof: "static wiring + grade-a-blockers-tests (api-guard-tests)",
    counterpart: "validate:grade-a-blockers-tests",
  },
  {
    id: "billing",
    npm: "validate:billing",
    risk: "high",
    score: 4,
    proof: "validate:billing + billing-tests in blockers",
    counterpart: "validate:grade-a-blockers-tests",
  },
  {
    id: "stripe-live",
    npm: "validate:stripe-live",
    risk: "high",
    score: 4,
    proof: "code + price lookup; live billing status file for webhook/checkout",
    counterpart: "live_billing_proof_status.json",
  },
  {
    id: "account-deletion",
    npm: "validate:hostile-proof",
    risk: "high",
    score: 4,
    proof: "blockers + hostile-proof E2E POST /api/account/delete",
  },
  {
    id: "journal",
    npm: "validate:journal",
    risk: "high",
    score: 4,
    proof: "validate:journal + journal-server/persistence blockers",
  },
  {
    id: "rate-limits",
    npm: "validate:rate-limits",
    risk: "high",
    score: 4,
    proof: "validate:rate-limits + rate-limit-tests + staging durable check",
  },
  {
    id: "internal-routes",
    npm: "validate:internal-routes",
    risk: "high",
    score: 4,
    proof: "static guards + runtime-proof/hostile internal 404 E2E",
    counterpart: "validate:runtime-proof",
  },
  {
    id: "privacy-logs",
    npm: "validate:privacy-logs",
    risk: "high",
    score: 4,
    proof: "static scan + privacy-logs-tests runtime",
    counterpart: "validate:privacy-logs-tests",
  },
  {
    id: "accessibility-full",
    npm: "validate:accessibility-full",
    risk: "high",
    score: 4,
    proof: "a11y full + dynamic + dynamic-permutations + screen-reader-structure",
    counterpart: "test:a11y:full, test:a11y:dynamic, test:a11y:dynamic-permutations",
  },
  {
    id: "staging-proof",
    npm: "validate:staging-proof",
    risk: "high",
    score: 5,
    proof: "live staging checks + status files; STAGING_BLOCKED locally",
  },
  {
    id: "device-proof",
    npm: "validate:device-proof",
    risk: "high",
    score: 5,
    proof: "device_proof_signoff.json — DEVICE_BLOCKED without fresh sign-off",
  },
  {
    id: "mobile-layout",
    npm: "validate:ui-final",
    risk: "high",
    score: 4,
    proof: "ui-mobile-375 overflow E2E",
    counterpart: "test:e2e:ui-mobile",
  },
  {
    id: "resurfacing-feedback",
    npm: "validate:grade-a-blockers-tests",
    risk: "high",
    score: 4,
    proof: "resurfacing-feedback-tests in blockers",
  },
  {
    id: "export-isolation",
    npm: "validate:runtime-proof",
    risk: "high",
    score: 4,
    proof: "runtime-proof export HTML + journal auth E2E",
  },
  {
    id: "debug-surface",
    npm: "validate:debug-surface",
    risk: "high",
    score: 4,
    proof: "static + ui-debug-regression E2E via validate:ui-final",
  },
  {
    id: "production-env",
    npm: "validate:production-env",
    risk: "high",
    score: 4,
    proof: "runtime strict validation; DEPLOY_BLOCKED locally",
  },
  {
    id: "deploy-secrets",
    npm: "validate:deploy-secrets",
    risk: "high",
    score: 5,
    proof: "live deploy verification — never faked locally",
  },
  {
    id: "internal-routes-static",
    npm: "validate:internal-routes",
    risk: "medium",
    score: 3,
    proof: "static middleware matrix + E2E 404 in proof suites",
  },
  {
    id: "health",
    npm: "validate:health",
    risk: "medium",
    score: 3,
    proof: "static health route contract + runtime-proof health fetch",
  },
];
