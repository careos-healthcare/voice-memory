/**
 * Defence in depth for cross-account writes.
 *
 * The authenticated server session is always authoritative: nothing here can
 * widen a caller's scope. What this adds is a *declared* binding — the client
 * states which account and archive it believes it is acting as, and the server
 * refuses the request when that belief is stale.
 *
 * This closes the window where a client that has just switched accounts still
 * has an in-flight request queued for the previous owner.
 */

export const OWNER_SCOPE_MISMATCH = "OWNER_SCOPE_MISMATCH" as const;

export const EXPECTED_ACCOUNT_HEADER = "x-vm-expected-account-id";
export const EXPECTED_ARCHIVE_HEADER = "x-vm-expected-archive-id";

export interface OwnerScopeClaim {
  expectedAccountId?: string | null;
  expectedArchiveId?: string | null;
}

export interface OwnerScopeRejection {
  code: typeof OWNER_SCOPE_MISMATCH;
  status: 409;
  message: string;
  /** Metadata only — never the rejected content. */
  log: { declaredAccountPresent: boolean; archiveScoped: boolean };
}

function readHeader(request: Request, name: string): string | null {
  const value = request.headers.get(name);
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
}

export function readOwnerScopeClaim(
  request: Request,
  body?: OwnerScopeClaim | null,
): OwnerScopeClaim {
  return {
    expectedAccountId:
      readHeader(request, EXPECTED_ACCOUNT_HEADER) ??
      body?.expectedAccountId?.toString().trim() ??
      null,
    expectedArchiveId:
      readHeader(request, EXPECTED_ARCHIVE_HEADER) ??
      body?.expectedArchiveId?.toString().trim() ??
      null,
  };
}

/**
 * Returns a rejection when the client's declared account does not match the
 * authenticated subject. A request that declares nothing is accepted and
 * remains constrained by the session alone.
 */
export function checkOwnerScope(
  claim: OwnerScopeClaim,
  sessionUserId: string,
): OwnerScopeRejection | null {
  const declared = claim.expectedAccountId?.trim();
  if (!declared) return null;
  if (declared === sessionUserId) return null;
  return {
    code: OWNER_SCOPE_MISMATCH,
    status: 409,
    message:
      "This request was prepared for a different account and was not applied.",
    log: {
      declaredAccountPresent: true,
      archiveScoped: Boolean(claim.expectedArchiveId),
    },
  };
}
