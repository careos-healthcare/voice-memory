#!/usr/bin/env node
/**
 * Guards the server-side consent revocation invariants, then runs the
 * behavioural suite.
 *
 * The structural checks exist because the behavioural ones can be satisfied by
 * code that a later refactor quietly removes: a `verify` path that stops
 * consulting the revocation list, a cleanup job that deletes revocation rows,
 * or a rate limiter that stands between a user and revoking access.
 */
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { runConsentRenewalTests } from "../packages/shared/lib/server/consent-renewal-tests.ts";
import { runConsentRevocationTests } from "../packages/shared/lib/server/consent-revocation-tests.ts";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const failures = [];

function readSource(relativePath) {
  try {
    return readFileSync(path.join(repoRoot, relativePath), "utf8");
  } catch {
    return null;
  }
}

function requireIn(relativePath, needles) {
  const source = readSource(relativePath);
  if (source == null) {
    failures.push(`${relativePath}: expected file is missing`);
    return;
  }
  for (const needle of needles) {
    if (!source.includes(needle)) {
      failures.push(`${relativePath}: expected to contain \`${needle}\``);
    }
  }
}

// 1. Both verify paths consult the revocation list.
requireIn("packages/shared/lib/server/caregiver-consent-crypto.ts", [
  "isConsentTokenRevoked",
]);
requireIn("packages/shared/lib/server/coach-consent-crypto.ts", [
  "isConsentTokenRevoked",
]);

// 2. The revoke route exists and is session gated.
requireIn("apps/api/app/api/coach/consent/revoke/route.ts", [
  "getServerSession",
  "handleConsentRevocation",
  "AUTH_REQUIRED",
]);

// 3. Revocation records are never deleted or expired.
const storeFiles = [
  "packages/shared/lib/server/consent-revocation-store.ts",
  "packages/shared/lib/server/consent-revoke-handler.ts",
  "packages/shared/lib/server/db.ts",
];
for (const relativePath of storeFiles) {
  const source = readSource(relativePath);
  if (source == null) {
    failures.push(`${relativePath}: expected file is missing`);
    continue;
  }
  if (/DELETE\s+FROM\s+consent_grants/i.test(source)) {
    failures.push(
      `${relativePath}: revocation records must outlive the tokens they revoke — no DELETE on consent_grants`,
    );
  }
  if (/consent_grants[\s\S]{0,400}?\bEXPIRE\b/i.test(source)) {
    failures.push(
      `${relativePath}: the revocation list must not carry an expiry`,
    );
  }
}

// 4. The revocation list does not live in the eviction-prone rate-limit Redis.
const storeSource = readSource(
  "packages/shared/lib/server/consent-revocation-store.ts",
);
if (storeSource && /redis/i.test(storeSource.replace(/\/\*[\s\S]*?\*\//g, ""))) {
  failures.push(
    "packages/shared/lib/server/consent-revocation-store.ts: the revocation list must not be backed by the rate-limit Redis, which can evict entries",
  );
}

// 5. There is no "assume not revoked" fallback.
if (storeSource && /catch[\s\S]{0,120}return false/.test(storeSource)) {
  failures.push(
    "packages/shared/lib/server/consent-revocation-store.ts: a caught error must never resolve to `false` — that reinstates revoked access",
  );
}

// 6. Revoking is never blocked by the global rate limiter.
requireIn("apps/api/lib/rate-limit/constants.ts", [
  '"/api/coach/consent/revoke"',
]);

// 7. Renewal is owner-driven, and reuses the revoke path's proof of ownership
//    rather than accepting the caregiver's own token as authority to extend it.
requireIn("packages/shared/lib/server/consent-renewal-handler.ts", [
  "authorizeConsentRevocation",
  "verifyServerCaregiverConsentToken",
  "renewConsentGrant",
  "OWNER_CONFIRMATION_REQUIRED",
]);
requireIn("apps/api/app/api/coach/consent/renew/route.ts", [
  "getServerSession",
  "handleCaregiverConsentRenewal",
  "AUTH_REQUIRED",
]);

// 8. Renewal issues the successor and withdraws the predecessor in one step.
//    Split across two writes, an interruption strands two working credentials
//    for one arrangement — worse than the weekly re-grant it replaces.
const renewalSources = {
  postgres: /async renew\(input\)[\s\S]{0,400}?withDbTransaction/,
  filesystem: /async renew\(input\)[\s\S]{0,2000}?writeFileShapeAtomically/,
  lock: /FOR UPDATE/,
};
if (storeSource) {
  for (const [name, pattern] of Object.entries(renewalSources)) {
    if (!pattern.test(storeSource)) {
      failures.push(
        `packages/shared/lib/server/consent-revocation-store.ts: the ${name} renewal path must swap the grant in one indivisible step`,
      );
    }
  }
  if (!/renew\?\(/.test(storeSource)) {
    failures.push(
      "packages/shared/lib/server/consent-revocation-store.ts: `renew` must stay optional on the backend seam, so a store that cannot do it in one step refuses instead of emulating it",
    );
  }
}

// 9. Renewal stays under the global rate limiter. The revoke exemption is for
//    ending access, and continuing access does not inherit that argument.
const rateLimitSource = readSource("apps/api/lib/rate-limit/constants.ts");
if (rateLimitSource && rateLimitSource.includes('"/api/coach/consent/renew"')) {
  failures.push(
    "apps/api/lib/rate-limit/constants.ts: renewal must not be exempt from the global rate limiter — the exemption exists for revoking, not for extending",
  );
}

failures.push(...(await runConsentRevocationTests()).failures);
failures.push(...(await runConsentRenewalTests()).failures);

if (failures.length) {
  console.error("validate-consent-revocation failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-consent-revocation ok");
