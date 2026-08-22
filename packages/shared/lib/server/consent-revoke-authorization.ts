import "server-only";

import { caregiverConsentTokenSignatureIsValid } from "@/lib/server/caregiver-consent-crypto";
import { coachConsentTokenSignatureIsValid } from "@/lib/server/coach-consent-crypto";
import {
  getConsentGrantRecord,
  type ConsentGrantKind,
} from "@/lib/server/consent-revocation-store";
import type { MonitoringConsentToken } from "@/types/caregiver";
import type { CoachConsentToken } from "@/types/coach-client-relationship";

/**
 * Who may revoke a consent grant.
 *
 * Exactly one party: the archive owner — `subjectAccountId` for caregiver
 * grants, `clientAccountId` for coach grants. The caregiver or coach the grant
 * was issued to is never authorized here, for either their own grant or anyone
 * else's. Letting the holder of a grant touch the revocation list at all gives
 * them a lever over the owner's ability to end access, and the whole point of
 * this endpoint is that the owner's decision is final.
 *
 * Ownership is established from the server's own issuance registry where one
 * exists. For grants issued before the registry did, the caller may instead
 * present the signed token itself: only the owner named inside a
 * correctly-signed token is accepted, and the signature is checked without
 * regard to expiry so that a lapsed token can still be revoked.
 */

export type PresentedConsentToken =
  | { grantKind: "caregiverMonitoring"; token: MonitoringConsentToken }
  | { grantKind: "coachClient"; token: CoachConsentToken };

export interface ResolvedConsentGrantIdentity {
  grantKind: ConsentGrantKind;
  subjectAccountId: string;
  partyId: string;
  relationshipId: string | null;
  issuedAt: string | null;
  expiresAt: string | null;
}

export type ConsentRevokeAuthorization =
  | { allowed: true; identity: ResolvedConsentGrantIdentity; source: "registry" | "presented_token" }
  | { allowed: false; denialCode: "not_grant_owner" | "ownership_unproven" };

async function identityFromPresentedToken(
  presented: PresentedConsentToken,
  tokenId: string,
): Promise<ResolvedConsentGrantIdentity | null> {
  if (presented.token.tokenId !== tokenId) return null;

  if (presented.grantKind === "caregiverMonitoring") {
    const token = presented.token;
    if (!(await caregiverConsentTokenSignatureIsValid(token))) return null;
    return {
      grantKind: "caregiverMonitoring",
      subjectAccountId: token.subjectAccountId,
      partyId: token.caregiverId,
      relationshipId: null,
      issuedAt: token.issuedAt || null,
      expiresAt: token.expiresAt || null,
    };
  }

  const token = presented.token;
  if (!(await coachConsentTokenSignatureIsValid(token))) return null;
  return {
    grantKind: "coachClient",
    subjectAccountId: token.clientAccountId,
    partyId: token.coachId,
    relationshipId: token.relationshipId || null,
    issuedAt: token.issuedAt || null,
    expiresAt: token.expiresAt || null,
  };
}

/**
 * Throws `ConsentRevocationStoreUnavailableError` if the registry cannot be
 * read. Callers must surface that as a retryable failure rather than falling
 * back to the presented token, which would let a store outage downgrade the
 * authorization check.
 */
export async function authorizeConsentRevocation(input: {
  sessionUserId: string;
  tokenId: string;
  grantKind: ConsentGrantKind;
  presentedToken?: PresentedConsentToken | null;
}): Promise<ConsentRevokeAuthorization> {
  const record = await getConsentGrantRecord(input.tokenId);

  if (record) {
    if (record.subjectAccountId !== input.sessionUserId) {
      return { allowed: false, denialCode: "not_grant_owner" };
    }
    return {
      allowed: true,
      source: "registry",
      identity: {
        grantKind: record.grantKind,
        subjectAccountId: record.subjectAccountId,
        partyId: record.partyId,
        relationshipId: record.relationshipId,
        issuedAt: record.issuedAt,
        expiresAt: record.expiresAt,
      },
    };
  }

  if (!input.presentedToken) {
    return { allowed: false, denialCode: "ownership_unproven" };
  }

  const identity = await identityFromPresentedToken(
    input.presentedToken,
    input.tokenId,
  );
  if (!identity) {
    return { allowed: false, denialCode: "ownership_unproven" };
  }
  if (identity.subjectAccountId !== input.sessionUserId) {
    return { allowed: false, denialCode: "not_grant_owner" };
  }

  return { allowed: true, source: "presented_token", identity };
}
