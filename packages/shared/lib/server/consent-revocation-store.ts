import "server-only";

import fs from "node:fs";
import path from "node:path";

import {
  dbQuery,
  shouldUseFilesystemStorage,
  shouldUsePostgresStorage,
  withDbTransaction,
} from "@/lib/server/db";
import { resolveDataPath, writeJsonFile } from "@/lib/server/data-path";

/**
 * Server-side consent grant registry and revocation list.
 *
 * Two properties this file exists to hold:
 *
 * 1. **Revocation records outlive the tokens they revoke.** There is no TTL, no
 *    eviction policy and no cleanup job here, and there must never be one: a
 *    revocation that expires before its token resurrects the access it was
 *    meant to end. This is why the list is in Postgres and not in the Redis
 *    instance used for rate limiting — that client is configured with
 *    `enableOfflineQueue: false` and degrades to "disabled" whenever
 *    `REDIS_URL` is unset, and a revocation list that can silently read back
 *    as empty is worse than no revocation list at all, because it reports
 *    success while reinstating access.
 *
 * 2. **Reads fail loudly.** `isConsentTokenRevoked` throws
 *    `ConsentRevocationStoreUnavailableError` when it cannot establish the
 *    revocation status of a token. Every caller must treat that as a denial.
 *    There is deliberately no "assume not revoked" path in this module.
 */

export type ConsentGrantKind = "caregiverMonitoring" | "coachClient";

export function isConsentGrantKind(value: unknown): value is ConsentGrantKind {
  return value === "caregiverMonitoring" || value === "coachClient";
}

/** Thrown when revocation status could not be established. Never swallow this. */
export class ConsentRevocationStoreUnavailableError extends Error {
  constructor(cause: unknown) {
    super(
      `Consent revocation status is unavailable: ${
        cause instanceof Error ? cause.message : String(cause)
      }`,
    );
    this.name = "ConsentRevocationStoreUnavailableError";
    this.cause = cause;
  }
}

export interface ConsentGrantRecord {
  tokenId: string;
  grantKind: ConsentGrantKind;
  /** The archive owner — the only account allowed to revoke. */
  subjectAccountId: string;
  /** The caregiver or coach the grant was issued to. */
  partyId: string;
  relationshipId: string | null;
  issuedAt: string | null;
  expiresAt: string | null;
  revokedAt: string | null;
  revokedBy: string | null;
  revocationReason: string | null;
}

export interface RecordConsentGrantInput {
  tokenId: string;
  grantKind: ConsentGrantKind;
  subjectAccountId: string;
  partyId: string;
  relationshipId?: string | null;
  issuedAt?: string | null;
  expiresAt?: string | null;
}

export interface RecordConsentRevocationInput extends RecordConsentGrantInput {
  revokedBy: string;
  revocationReason?: string | null;
  now?: Date;
}

export interface ConsentRevocationOutcome {
  tokenId: string;
  revokedAt: string;
  alreadyRevoked: boolean;
}

/**
 * Replaces one grant with a successor. Both halves land together or neither
 * does — see `ConsentRevocationBackend.renew`.
 */
export interface RenewConsentGrantInput {
  previousTokenId: string;
  /** The successor grant. Its `tokenId` must differ from `previousTokenId`. */
  replacement: RecordConsentGrantInput;
  /** Carried onto the predecessor's row when the registry never held one. */
  previousIssuedAt?: string | null;
  previousExpiresAt?: string | null;
  revokedBy: string;
  revocationReason?: string | null;
  now?: Date;
}

export interface ConsentGrantRenewalOutcome {
  previousTokenId: string;
  previousRevokedAt: string;
  newTokenId: string;
}

export type ConsentGrantRenewalDenialCode =
  | "previous_grant_revoked"
  | "renewal_token_id_reused"
  | "renewal_unsupported";

/**
 * Thrown when a renewal must not proceed. Distinct from
 * `ConsentRevocationStoreUnavailableError`: this one is a decision, not an
 * outage, and retrying it will reach the same answer.
 */
export class ConsentGrantNotRenewableError extends Error {
  constructor(readonly denialCode: ConsentGrantRenewalDenialCode) {
    super(`Consent grant cannot be renewed: ${denialCode}`);
    this.name = "ConsentGrantNotRenewableError";
  }
}

/**
 * The storage seam. Tests install a backend directly; production resolves one
 * from the database configuration.
 */
export interface ConsentRevocationBackend {
  readonly name: string;
  read(tokenId: string): Promise<ConsentGrantRecord | null>;
  upsertGrant(input: RecordConsentGrantInput): Promise<void>;
  revoke(input: RecordConsentRevocationInput): Promise<ConsentRevocationOutcome>;

  /**
   * Registers the successor and withdraws the predecessor as one indivisible
   * step, re-reading the predecessor's revocation state inside the same step.
   *
   * Optional, and deliberately so. A backend that cannot do this in one step
   * must leave it undefined rather than emulate it with two writes: an
   * interruption between "successor registered" and "predecessor withdrawn"
   * leaves two working credentials for one arrangement, which is worse than
   * the weekly re-grant this feature exists to avoid. `renewConsentGrant`
   * refuses when the method is absent, and the owner re-grants instead.
   */
  renew?(input: RenewConsentGrantInput): Promise<ConsentGrantRenewalOutcome>;
}

let backendOverride: ConsentRevocationBackend | null = null;

/** Test seam — pass `null` to restore the configured backend. */
export function setConsentRevocationBackendForTest(
  backend: ConsentRevocationBackend | null,
): void {
  backendOverride = backend;
}

function normalizeTimestamp(value: unknown): string | null {
  if (value == null) return null;
  const date = value instanceof Date ? value : new Date(String(value));
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString();
}

function rowToRecord(row: Record<string, unknown>): ConsentGrantRecord {
  const kind = String(row.grant_kind);
  return {
    tokenId: String(row.token_id),
    grantKind: isConsentGrantKind(kind) ? kind : "coachClient",
    subjectAccountId: String(row.subject_account_id),
    partyId: String(row.party_id ?? ""),
    relationshipId: row.relationship_id == null ? null : String(row.relationship_id),
    issuedAt: normalizeTimestamp(row.issued_at),
    expiresAt: normalizeTimestamp(row.expires_at),
    revokedAt: normalizeTimestamp(row.revoked_at),
    revokedBy: row.revoked_by == null ? null : String(row.revoked_by),
    revocationReason:
      row.revocation_reason == null ? null : String(row.revocation_reason),
  };
}

const postgresBackend: ConsentRevocationBackend = {
  name: "postgres",

  async read(tokenId) {
    const result = await dbQuery<Record<string, unknown>>(
      `SELECT * FROM consent_grants WHERE token_id = $1 LIMIT 1`,
      [tokenId],
    );
    const row = result.rows[0];
    return row ? rowToRecord(row) : null;
  },

  async upsertGrant(input) {
    await dbQuery(
      `INSERT INTO consent_grants (
         token_id, grant_kind, subject_account_id, party_id, relationship_id,
         issued_at, expires_at
       ) VALUES ($1, $2, $3, $4, $5, $6::timestamptz, $7::timestamptz)
       ON CONFLICT (token_id) DO UPDATE SET
         grant_kind = EXCLUDED.grant_kind,
         subject_account_id = EXCLUDED.subject_account_id,
         party_id = EXCLUDED.party_id,
         relationship_id = EXCLUDED.relationship_id,
         issued_at = EXCLUDED.issued_at,
         expires_at = EXCLUDED.expires_at,
         updated_at = now()`,
      [
        input.tokenId,
        input.grantKind,
        input.subjectAccountId,
        input.partyId,
        input.relationshipId ?? null,
        input.issuedAt ?? null,
        input.expiresAt ?? null,
      ],
    );
  },

  async revoke(input) {
    const revokedAt = (input.now ?? new Date()).toISOString();
    // The first revocation wins: `revoked_at` is only written where it is
    // currently NULL, so a later call cannot move the timestamp forward and a
    // concurrent second call cannot race it backwards.
    const result = await dbQuery<Record<string, unknown>>(
      `INSERT INTO consent_grants (
         token_id, grant_kind, subject_account_id, party_id, relationship_id,
         issued_at, expires_at, revoked_at, revoked_by, revocation_reason
       ) VALUES (
         $1, $2, $3, $4, $5, $6::timestamptz, $7::timestamptz,
         $8::timestamptz, $9, $10
       )
       ON CONFLICT (token_id) DO UPDATE SET
         revoked_at = COALESCE(consent_grants.revoked_at, EXCLUDED.revoked_at),
         revoked_by = COALESCE(consent_grants.revoked_by, EXCLUDED.revoked_by),
         revocation_reason = COALESCE(
           consent_grants.revocation_reason, EXCLUDED.revocation_reason
         ),
         updated_at = now()
       RETURNING revoked_at`,
      [
        input.tokenId,
        input.grantKind,
        input.subjectAccountId,
        input.partyId,
        input.relationshipId ?? null,
        input.issuedAt ?? null,
        input.expiresAt ?? null,
        revokedAt,
        input.revokedBy,
        input.revocationReason ?? null,
      ],
    );

    const storedAt = normalizeTimestamp(result.rows[0]?.revoked_at) ?? revokedAt;
    return {
      tokenId: input.tokenId,
      revokedAt: storedAt,
      alreadyRevoked: storedAt !== revokedAt,
    };
  },

  async renew(input) {
    const revokedAt = (input.now ?? new Date()).toISOString();

    return withDbTransaction(async (client) => {
      // `FOR UPDATE` holds the predecessor row for the life of the
      // transaction, so a revoke racing this renewal either lands first — and
      // is seen below — or waits and then finds the row already withdrawn.
      // Without the lock, a withdrawal decided while the successor was being
      // signed could be overwritten by a credential the owner had already
      // stopped consenting to.
      const locked = await client.query<Record<string, unknown>>(
        `SELECT revoked_at FROM consent_grants WHERE token_id = $1 FOR UPDATE`,
        [input.previousTokenId],
      );
      const lockedRow = locked.rows[0];
      if (lockedRow && normalizeTimestamp(lockedRow.revoked_at) != null) {
        throw new ConsentGrantNotRenewableError("previous_grant_revoked");
      }

      await client.query(
        `INSERT INTO consent_grants (
           token_id, grant_kind, subject_account_id, party_id, relationship_id,
           issued_at, expires_at
         ) VALUES ($1, $2, $3, $4, $5, $6::timestamptz, $7::timestamptz)
         ON CONFLICT (token_id) DO UPDATE SET
           grant_kind = EXCLUDED.grant_kind,
           subject_account_id = EXCLUDED.subject_account_id,
           party_id = EXCLUDED.party_id,
           relationship_id = EXCLUDED.relationship_id,
           issued_at = EXCLUDED.issued_at,
           expires_at = EXCLUDED.expires_at,
           updated_at = now()`,
        [
          input.replacement.tokenId,
          input.replacement.grantKind,
          input.replacement.subjectAccountId,
          input.replacement.partyId,
          input.replacement.relationshipId ?? null,
          input.replacement.issuedAt ?? null,
          input.replacement.expiresAt ?? null,
        ],
      );

      const withdrawn = await client.query<Record<string, unknown>>(
        `INSERT INTO consent_grants (
           token_id, grant_kind, subject_account_id, party_id, relationship_id,
           issued_at, expires_at, revoked_at, revoked_by, revocation_reason
         ) VALUES (
           $1, $2, $3, $4, $5, $6::timestamptz, $7::timestamptz,
           $8::timestamptz, $9, $10
         )
         ON CONFLICT (token_id) DO UPDATE SET
           revoked_at = COALESCE(consent_grants.revoked_at, EXCLUDED.revoked_at),
           revoked_by = COALESCE(consent_grants.revoked_by, EXCLUDED.revoked_by),
           revocation_reason = COALESCE(
             consent_grants.revocation_reason, EXCLUDED.revocation_reason
           ),
           updated_at = now()
         RETURNING revoked_at`,
        [
          input.previousTokenId,
          input.replacement.grantKind,
          input.replacement.subjectAccountId,
          input.replacement.partyId,
          input.replacement.relationshipId ?? null,
          input.previousIssuedAt ?? null,
          input.previousExpiresAt ?? null,
          revokedAt,
          input.revokedBy,
          input.revocationReason ?? null,
        ],
      );

      return {
        previousTokenId: input.previousTokenId,
        previousRevokedAt:
          normalizeTimestamp(withdrawn.rows[0]?.revoked_at) ?? revokedAt,
        newTokenId: input.replacement.tokenId,
      };
    });
  },
};

interface FileShape {
  grants: Record<string, ConsentGrantRecord>;
}

function consentGrantsFilePath(): string {
  return resolveDataPath("consent", "consent-grants.json");
}

/**
 * Deliberately not `readJsonFile`, which swallows a parse error and returns the
 * fallback. Here that would turn a corrupted store into an empty revocation
 * list, silently reinstating every revoked grant. A missing file is an empty
 * list — nothing has been revoked yet — but an unreadable one throws.
 */
function readFileShape(): FileShape {
  const filePath = consentGrantsFilePath();
  if (!fs.existsSync(filePath)) return { grants: {} };

  const parsed = JSON.parse(fs.readFileSync(filePath, "utf8")) as unknown;
  if (
    !parsed ||
    typeof parsed !== "object" ||
    typeof (parsed as FileShape).grants !== "object" ||
    (parsed as FileShape).grants == null
  ) {
    throw new Error(
      `Consent revocation store at ${filePath} is unreadable — refusing to treat it as empty.`,
    );
  }
  return parsed as FileShape;
}

/**
 * Writes the whole registry through a same-directory temporary file and a
 * rename, so a reader sees either the previous document or the next one and
 * never a half-written mixture of the two.
 *
 * Used only by `renew`, where the write carries two linked changes — the
 * successor appearing and the predecessor being withdrawn — and a torn file
 * would leave the pair inconsistent. The plain `writeJsonFile` path is left
 * alone for single-grant writes, which have no such pairing.
 */
function writeFileShapeAtomically(shape: FileShape): void {
  const filePath = consentGrantsFilePath();
  const scratchPath = resolveDataPath(
    "consent",
    `consent-grants.${process.pid}.${Date.now()}.staged`,
  );
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(scratchPath, JSON.stringify(shape, null, 2), "utf8");
  fs.renameSync(scratchPath, filePath);
}

/**
 * Development backend. Still durable across restarts — a JSON file under the
 * data root, never an in-memory map, so a local run behaves the same way a
 * deployed one does. Production never reaches this: `shouldUseFilesystemStorage`
 * is false whenever `NODE_ENV === "production"`.
 */
const filesystemBackend: ConsentRevocationBackend = {
  name: "filesystem",

  async read(tokenId) {
    return readFileShape().grants[tokenId] ?? null;
  },

  async upsertGrant(input) {
    const shape = readFileShape();
    const existing = shape.grants[input.tokenId];
    shape.grants[input.tokenId] = {
      tokenId: input.tokenId,
      grantKind: input.grantKind,
      subjectAccountId: input.subjectAccountId,
      partyId: input.partyId,
      relationshipId: input.relationshipId ?? null,
      issuedAt: input.issuedAt ?? null,
      expiresAt: input.expiresAt ?? null,
      revokedAt: existing?.revokedAt ?? null,
      revokedBy: existing?.revokedBy ?? null,
      revocationReason: existing?.revocationReason ?? null,
    };
    writeJsonFile(consentGrantsFilePath(), shape);
  },

  async revoke(input) {
    const shape = readFileShape();
    const existing = shape.grants[input.tokenId];
    if (existing?.revokedAt) {
      return {
        tokenId: input.tokenId,
        revokedAt: existing.revokedAt,
        alreadyRevoked: true,
      };
    }

    const revokedAt = (input.now ?? new Date()).toISOString();
    shape.grants[input.tokenId] = {
      tokenId: input.tokenId,
      grantKind: input.grantKind,
      subjectAccountId: existing?.subjectAccountId ?? input.subjectAccountId,
      partyId: existing?.partyId ?? input.partyId,
      relationshipId: existing?.relationshipId ?? input.relationshipId ?? null,
      issuedAt: existing?.issuedAt ?? input.issuedAt ?? null,
      expiresAt: existing?.expiresAt ?? input.expiresAt ?? null,
      revokedAt,
      revokedBy: input.revokedBy,
      revocationReason: input.revocationReason ?? null,
    };
    writeJsonFile(consentGrantsFilePath(), shape);
    return { tokenId: input.tokenId, revokedAt, alreadyRevoked: false };
  },

  async renew(input) {
    const shape = readFileShape();
    const previous = shape.grants[input.previousTokenId];
    if (previous?.revokedAt) {
      throw new ConsentGrantNotRenewableError("previous_grant_revoked");
    }

    const revokedAt = (input.now ?? new Date()).toISOString();

    shape.grants[input.previousTokenId] = {
      tokenId: input.previousTokenId,
      grantKind: previous?.grantKind ?? input.replacement.grantKind,
      subjectAccountId:
        previous?.subjectAccountId ?? input.replacement.subjectAccountId,
      partyId: previous?.partyId ?? input.replacement.partyId,
      relationshipId:
        previous?.relationshipId ?? input.replacement.relationshipId ?? null,
      issuedAt: previous?.issuedAt ?? input.previousIssuedAt ?? null,
      expiresAt: previous?.expiresAt ?? input.previousExpiresAt ?? null,
      revokedAt,
      revokedBy: input.revokedBy,
      revocationReason: input.revocationReason ?? null,
    };

    shape.grants[input.replacement.tokenId] = {
      tokenId: input.replacement.tokenId,
      grantKind: input.replacement.grantKind,
      subjectAccountId: input.replacement.subjectAccountId,
      partyId: input.replacement.partyId,
      relationshipId: input.replacement.relationshipId ?? null,
      issuedAt: input.replacement.issuedAt ?? null,
      expiresAt: input.replacement.expiresAt ?? null,
      revokedAt: null,
      revokedBy: null,
      revocationReason: null,
    };

    writeFileShapeAtomically(shape);

    return {
      previousTokenId: input.previousTokenId,
      previousRevokedAt: revokedAt,
      newTokenId: input.replacement.tokenId,
    };
  },
};

function resolveBackend(): ConsentRevocationBackend {
  if (backendOverride) return backendOverride;
  if (shouldUsePostgresStorage()) return postgresBackend;
  if (shouldUseFilesystemStorage()) return filesystemBackend;
  // Production without DATABASE_URL. There is no safe third option: without a
  // revocation list we cannot tell a live grant from a withdrawn one, so we
  // refuse rather than guess.
  throw new ConsentRevocationStoreUnavailableError(
    new Error("No durable consent revocation store is configured."),
  );
}

/**
 * Records that a token was issued, so the archive owner can revoke it later
 * without still holding the token themselves. Throws if the write fails, and
 * the issue route lets that fail the issuance: a grant whose registry row is
 * missing can only be revoked by someone who still has the token, and a grant
 * that might not be revocable should not be created.
 */
export async function recordConsentGrantIssued(
  input: RecordConsentGrantInput,
): Promise<void> {
  await resolveBackend().upsertGrant(input);
}

/** Looks up the issuance record used to authorize a revoke. */
export async function getConsentGrantRecord(
  tokenId: string,
): Promise<ConsentGrantRecord | null> {
  try {
    return await resolveBackend().read(tokenId);
  } catch (error) {
    throw new ConsentRevocationStoreUnavailableError(error);
  }
}

/** Idempotent. Revoking an already-revoked token returns the original timestamp. */
export async function recordConsentRevocation(
  input: RecordConsentRevocationInput,
): Promise<ConsentRevocationOutcome> {
  try {
    return await resolveBackend().revoke(input);
  } catch (error) {
    throw new ConsentRevocationStoreUnavailableError(error);
  }
}

/**
 * Swaps a live grant for a freshly issued successor in one indivisible step.
 *
 * The step is the whole point. Registering the successor first and withdrawing
 * the predecessor afterwards would, if interrupted between the two, leave two
 * working credentials for one arrangement — and an unregistered token is not
 * revoked, so the stale one keeps verifying. Both halves therefore happen
 * inside the backend, which re-reads the predecessor's withdrawal state as
 * part of the same step so a revoke decided while the successor was being
 * signed still wins.
 *
 * Refuses outright when the configured backend does not offer the step. That
 * fails toward no renewal at all, which the owner can resolve by granting
 * again — the direction that leaves fewer credentials in circulation, not
 * more.
 */
export async function renewConsentGrant(
  input: RenewConsentGrantInput,
): Promise<ConsentGrantRenewalOutcome> {
  if (input.replacement.tokenId === input.previousTokenId) {
    throw new ConsentGrantNotRenewableError("renewal_token_id_reused");
  }

  let backend: ConsentRevocationBackend;
  try {
    backend = resolveBackend();
  } catch (error) {
    throw new ConsentRevocationStoreUnavailableError(error);
  }

  const renew = backend.renew?.bind(backend);
  if (!renew) {
    throw new ConsentGrantNotRenewableError("renewal_unsupported");
  }

  try {
    return await renew(input);
  } catch (error) {
    if (error instanceof ConsentGrantNotRenewableError) throw error;
    throw new ConsentRevocationStoreUnavailableError(error);
  }
}

/**
 * The gate `verify` calls on every request.
 *
 * Throws rather than returning a boolean when the answer is unknown. Callers
 * must convert that into a denial; anything else reinstates access to a private
 * journal during an outage.
 */
export async function isConsentTokenRevoked(tokenId: string): Promise<boolean> {
  if (!tokenId) {
    // An unidentifiable token cannot be checked against the list, so it cannot
    // be trusted.
    throw new ConsentRevocationStoreUnavailableError(
      new Error("Consent token has no tokenId to check against the revocation list."),
    );
  }

  let record: ConsentGrantRecord | null;
  try {
    record = await resolveBackend().read(tokenId);
  } catch (error) {
    throw new ConsentRevocationStoreUnavailableError(error);
  }

  return record?.revokedAt != null;
}
