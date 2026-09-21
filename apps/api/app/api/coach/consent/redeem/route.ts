import { NextResponse } from "next/server";

import { apiErrorResponse } from "@/lib/server/api-error-response";
import {
  redeemByLinkToken,
  redeemByManualCode,
} from "@/lib/server/caregiver-redemption-store";
import { getConsentGrantRecord } from "@/lib/server/consent-revocation-store";
import { issueServerCaregiverConsentToken } from "@/lib/server/caregiver-consent-crypto";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Redeems a caregiver invitation -- either via the Universal Link's embedded
 * token, or the short manual fallback code plus its reference. Deliberately
 * NOT session-gated, unlike issue/revoke/verify: the caregiver redeeming a
 * code has no existing session on this account by definition. Relies on the
 * global rate limiter (server.entry.ts) rather than a route-specific one --
 * this path is not in GLOBAL_RATE_LIMIT_EXEMPT_PATHS, so it is covered
 * automatically.
 */
export async function POST(request: Request) {
  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return apiErrorResponse({
      code: "INVALID_BODY",
      route: "coach/consent/redeem",
      internalCategory: "validation",
      status: 400,
    });
  }
  const linkToken = typeof body.linkToken === "string" ? body.linkToken.trim() : "";
  const reference = typeof body.reference === "string" ? body.reference.trim() : "";
  const manualCode = typeof body.code === "string" ? body.code.trim() : "";

  if (!linkToken && !(reference && manualCode)) {
    return apiErrorResponse({
      code: "INVALID_REDEMPTION_REQUEST",
      route: "coach/consent/redeem",
      internalCategory: "validation",
      status: 400,
    });
  }

  let outcome;
  try {
    outcome = linkToken
      ? await redeemByLinkToken(linkToken)
      : await redeemByManualCode(reference, manualCode);
  } catch (error) {
    return apiErrorResponse({
      code: "REDEMPTION_STORE_UNAVAILABLE",
      route: "coach/consent/redeem",
      internalCategory: "database_unavailable",
      status: 503,
    });
  }
  if (outcome.outcome === "not_found") {
    return apiErrorResponse({
      code: "REDEMPTION_NOT_FOUND",
      route: "coach/consent/redeem",
      internalCategory: "validation",
      status: 404,
    });
  }
  if (outcome.outcome === "expired") {
    return apiErrorResponse({
      code: "REDEMPTION_EXPIRED",
      route: "coach/consent/redeem",
      internalCategory: "validation",
      status: 410,
    });
  }
  if (outcome.outcome === "locked") {
    return apiErrorResponse({
      code: "REDEMPTION_LOCKED",
      route: "coach/consent/redeem",
      internalCategory: "rate_limited",
      status: 429,
    });
  }
  if (outcome.outcome === "mismatch") {
    return apiErrorResponse({
      code: "REDEMPTION_CODE_MISMATCH",
      route: "coach/consent/redeem",
      internalCategory: "validation",
      status: 400,
    });
  }
  if (outcome.outcome === "already_redeemed") {
    return apiErrorResponse({
      code: "REDEMPTION_ALREADY_USED",
      route: "coach/consent/redeem",
      internalCategory: "conflict",
      status: 409,
    });
  }
  // outcome.outcome === "redeemed" from here.
  const grant = await getConsentGrantRecord(outcome.record.tokenId);
  if (!grant) {
    return apiErrorResponse({
      code: "REDEMPTION_GRANT_MISSING",
      route: "coach/consent/redeem",
      internalCategory: "internal_error",
      status: 500,
    });
  }
  // A code that redeemed successfully for an already-revoked grant must not
  // produce a working token -- the redemption-code store has no knowledge of
  // consent_grants' revocation state, so this has to be checked here.
  if (grant.revokedAt) {
    return apiErrorResponse({
      code: "REDEMPTION_GRANT_REVOKED",
      route: "coach/consent/redeem",
      internalCategory: "forbidden",
      status: 403,
    });
  }
  if (!grant.permissions || !grant.issuedAt || !grant.expiresAt) {
    // Matches migration 008's own design: a grant recorded before permissions
    // existed, or with any of these fields missing, must read as
    // "cannot redeem" -- never as an empty or default grant.
    return apiErrorResponse({
      code: "REDEMPTION_GRANT_INCOMPLETE",
      route: "coach/consent/redeem",
      internalCategory: "internal_error",
      status: 500,
    });
  }
  const issuedAtMs = new Date(grant.issuedAt).getTime();
  const expiresAtMs = new Date(grant.expiresAt).getTime();

  const token = await issueServerCaregiverConsentToken({
    tokenId: grant.tokenId,
    subjectAccountId: grant.subjectAccountId,
    caregiverId: grant.partyId,
    permissions: grant.permissions,
    now: new Date(issuedAtMs),
    ttlMs: expiresAtMs - issuedAtMs,
  });

  return NextResponse.json({ ok: true, token });
}
