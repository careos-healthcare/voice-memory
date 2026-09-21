import "server-only";
import { randomUUID } from "node:crypto";

import { dbQuery, shouldUseFilesystemStorage, shouldUsePostgresStorage } from "@/lib/server/db";
import { resolveDataPath, writeJsonFile } from "@/lib/server/data-path";
import { ConsentRevocationStoreUnavailableError } from "@/lib/server/consent-revocation-store";
import { hashCaregiverRedemptionCode } from "@/lib/server/caregiver-consent-crypto";
import { evaluateCodeAttempt } from "@/lib/auth/auth-code-policy";
import fs from "node:fs";
import path from "node:path";

/**
 * Single-use redemption codes for delivering a caregiver consent grant to a
 * second device -- see docs/sql/009_caregiver_redemption_codes.sql for the
 * full design rationale (why this is its own table, why there are two code
 * formats, why manual codes need a non-secret reference to be findable).
 *
 * Structured to mirror consent-revocation-store.ts exactly: a backend
 * interface, two real implementations (Postgres for production, a
 * filesystem JSON file for local dev -- shouldUseFilesystemStorage is false
 * whenever NODE_ENV === "production"), a test-injection seam, and a small
 * set of clean public functions that hide backend selection entirely.
 */

export interface RedemptionCodeRecord {
  id: string;
  tokenId: string;
  reference: string;
  linkTokenHash: string;
  manualCodeHash: string;
  manualCodeAttempts: number;
  expiresAt: string;
  redeemedAt: string | null;
}

export interface IssueRedemptionCodeInput {
  tokenId: string;
  reference: string;
  linkTokenHash: string;
  manualCodeHash: string;
  expiresAt: string;
}

/** Outcome of one redemption attempt against a specific reference. */
export type RedeemAttemptOutcome =
  | { outcome: "redeemed"; record: RedemptionCodeRecord }
  | { outcome: "already_redeemed" }
  | { outcome: "expired" }
  | { outcome: "locked" }
  | { outcome: "mismatch" }
  | { outcome: "not_found" };

export interface RedemptionCodeBackend {
  readonly name: string;
  issue(input: IssueRedemptionCodeInput): Promise<void>;
  findByReference(reference: string): Promise<RedemptionCodeRecord | null>;
  findByLinkTokenHash(hash: string): Promise<RedemptionCodeRecord | null>;
  markRedeemed(id: string, redeemedAtIso: string): Promise<boolean>;
  incrementManualAttempts(id: string): Promise<number>;
}

function rowToRedemptionRecord(row: Record<string, unknown>): RedemptionCodeRecord {
  return {
    id: String(row.id),
    tokenId: String(row.token_id),
    reference: String(row.reference),
    linkTokenHash: String(row.link_token_hash),
    manualCodeHash: String(row.manual_code_hash),
    manualCodeAttempts: Number(row.manual_code_attempts ?? 0),
    expiresAt: new Date(String(row.expires_at)).toISOString(),
    redeemedAt: row.redeemed_at == null ? null : new Date(String(row.redeemed_at)).toISOString(),
  };
}

const postgresBackend: RedemptionCodeBackend = {
  name: "postgres",
  async issue(input) {
    await dbQuery(
      `INSERT INTO caregiver_redemption_codes (
         id, token_id, reference, link_token_hash, manual_code_hash, expires_at
       ) VALUES ($1, $2, $3, $4, $5, $6::timestamptz)`,
      [
        randomUUID(),
        input.tokenId,
        input.reference,
        input.linkTokenHash,
        input.manualCodeHash,
        input.expiresAt,
      ],
    );
  },
  async findByReference(reference) {
    const result = await dbQuery<Record<string, unknown>>(
      `SELECT * FROM caregiver_redemption_codes WHERE reference = $1 LIMIT 1`,
      [reference],
    );
    const row = result.rows[0];
    return row ? rowToRedemptionRecord(row) : null;
  },
  async findByLinkTokenHash(hash) {
    const result = await dbQuery<Record<string, unknown>>(
      `SELECT * FROM caregiver_redemption_codes WHERE link_token_hash = $1 LIMIT 1`,
      [hash],
    );
    const row = result.rows[0];
    return row ? rowToRedemptionRecord(row) : null;
  },
  async markRedeemed(id, redeemedAtIso) {
    // COALESCE-based "first one wins", same pattern as revoke() in
    // consent-revocation-store.ts: redeemed_at is only written where it is
    // currently NULL, so a concurrent second redemption cannot also succeed.
    const result = await dbQuery<{ redeemed_at: string | null }>(
      `UPDATE caregiver_redemption_codes
       SET redeemed_at = COALESCE(redeemed_at, $2::timestamptz)
       WHERE id = $1
       RETURNING redeemed_at`,
      [id, redeemedAtIso],
    );
    const row = result.rows[0];
    if (!row) return false;
    // Compared as instants, not raw strings: Postgres's round-tripped
    // serialization of the timestamptz we sent isn't guaranteed to be
    // byte-for-byte identical to the ISO string we generated, even for the
    // exact same moment -- a string mismatch here would wrongly report
    // "someone else won" even when this call actually succeeded.
    if (row.redeemed_at == null) return false;
    return new Date(row.redeemed_at).getTime() === new Date(redeemedAtIso).getTime();
  },
  async incrementManualAttempts(id) {
    const result = await dbQuery<{ manual_code_attempts: number }>(
      `UPDATE caregiver_redemption_codes
       SET manual_code_attempts = manual_code_attempts + 1
       WHERE id = $1
       RETURNING manual_code_attempts`,
      [id],
    );
    return Number(result.rows[0]?.manual_code_attempts ?? 0);
  },
};

interface RedemptionFileShape {
  codes: Record<string, RedemptionCodeRecord>;
  referenceIndex: Record<string, string>;
  linkHashIndex: Record<string, string>;
}

function redemptionCodesFilePath(): string {
  return resolveDataPath("consent", "caregiver-redemption-codes.json");
}

/**
 * Deliberately not a silent-fallback read, same reasoning as
 * consent-revocation-store.ts's readFileShape: a corrupted file reading back
 * as empty would make a genuinely-redeemed code look never-redeemed, letting
 * it be redeemed a second time. A missing file is an empty store; an
 * unreadable one throws.
 */
function readRedemptionFileShape(): RedemptionFileShape {
  const filePath = redemptionCodesFilePath();
  if (!fs.existsSync(filePath)) {
    return { codes: {}, referenceIndex: {}, linkHashIndex: {} };
  }
  const parsed = JSON.parse(fs.readFileSync(filePath, "utf8")) as unknown;
  if (
    !parsed ||
    typeof parsed !== "object" ||
    !("codes" in parsed) ||
    !("referenceIndex" in parsed) ||
    !("linkHashIndex" in parsed)
  ) {
    throw new Error("Caregiver redemption codes file is malformed.");
  }
  return parsed as RedemptionFileShape;
}

const filesystemBackend: RedemptionCodeBackend = {
  name: "filesystem",
  async issue(input) {
    const shape = readRedemptionFileShape();
    const id = randomUUID();
    shape.codes[id] = {
      id,
      tokenId: input.tokenId,
      reference: input.reference,
      linkTokenHash: input.linkTokenHash,
      manualCodeHash: input.manualCodeHash,
      manualCodeAttempts: 0,
      expiresAt: input.expiresAt,
      redeemedAt: null,
    };
    shape.referenceIndex[input.reference] = id;
    shape.linkHashIndex[input.linkTokenHash] = id;
    writeJsonFile(redemptionCodesFilePath(), shape);
  },
  async findByReference(reference) {
    const shape = readRedemptionFileShape();
    const id = shape.referenceIndex[reference];
    return id ? shape.codes[id] ?? null : null;
  },
  async findByLinkTokenHash(hash) {
    const shape = readRedemptionFileShape();
    const id = shape.linkHashIndex[hash];
    return id ? shape.codes[id] ?? null : null;
  },
  async markRedeemed(id, redeemedAtIso) {
    const shape = readRedemptionFileShape();
    const record = shape.codes[id];
    if (!record) return false;
    if (record.redeemedAt) return false;
    record.redeemedAt = redeemedAtIso;
    writeJsonFile(redemptionCodesFilePath(), shape);
    return true;
  },
  async incrementManualAttempts(id) {
    const shape = readRedemptionFileShape();
    const record = shape.codes[id];
    if (!record) return 0;
    record.manualCodeAttempts += 1;
    writeJsonFile(redemptionCodesFilePath(), shape);
    return record.manualCodeAttempts;
  },
};

let backendOverride: RedemptionCodeBackend | null = null;

/** Test seam — pass `null` to restore the configured backend. */
export function setRedemptionCodeBackendForTest(
  backend: RedemptionCodeBackend | null,
): void {
  backendOverride = backend;
}

function resolveRedemptionBackend(): RedemptionCodeBackend {
  if (backendOverride) return backendOverride;
  if (shouldUsePostgresStorage()) return postgresBackend;
  if (shouldUseFilesystemStorage()) return filesystemBackend;
  // Same refusal as consent-revocation-store.ts's resolveBackend: production
  // without DATABASE_URL has no safe fallback here either.
  throw new ConsentRevocationStoreUnavailableError(
    new Error("No durable caregiver redemption code store is configured."),
  );
}

export async function issueRedemptionCode(
  input: IssueRedemptionCodeInput,
): Promise<void> {
  await resolveRedemptionBackend().issue(input);
}

export async function findRedemptionCodeByReference(
  reference: string,
): Promise<RedemptionCodeRecord | null> {
  return resolveRedemptionBackend().findByReference(reference);
}

export async function findRedemptionCodeByLinkTokenHash(
  hash: string,
): Promise<RedemptionCodeRecord | null> {
  return resolveRedemptionBackend().findByLinkTokenHash(hash);
}

/**
 * Redemption via the Universal Link's embedded token. No guessing is
 * possible here -- the record is found BY the token's hash, so if one is
 * found at all, it already matches. Unlike the manual-code path below,
 * there is no reference lookup and no evaluateCodeAttempt call: a wrong
 * link token simply finds no record, not a record with a mismatched hash.
 */
export async function redeemByLinkToken(
  linkToken: string,
  now: Date = new Date(),
): Promise<RedeemAttemptOutcome> {
  const backend = resolveRedemptionBackend();
  const record = await backend.findByLinkTokenHash(
    hashCaregiverRedemptionCode(linkToken.trim()),
  );
  if (!record) return { outcome: "not_found" };
  if (record.redeemedAt) return { outcome: "already_redeemed" };
  if (new Date(record.expiresAt).getTime() <= now.getTime()) {
    return { outcome: "expired" };
  }
  const redeemedAtIso = now.toISOString();
  const won = await backend.markRedeemed(record.id, redeemedAtIso);
  if (!won) return { outcome: "already_redeemed" };
  return { outcome: "redeemed", record: { ...record, redeemedAt: redeemedAtIso } };
}

/**
 * Redemption via the short, human-typeable fallback code. Found BY
 * reference first (not by hash), deliberately, so a wrong guess still
 * lands on the right row -- see the migration's own comment on `reference`
 * for why this matters: without it, evaluateCodeAttempt has nothing to
 * count a wrong guess against.
 */
export async function redeemByManualCode(
  reference: string,
  code: string,
  now: Date = new Date(),
): Promise<RedeemAttemptOutcome> {
  const backend = resolveRedemptionBackend();
  const record = await backend.findByReference(reference);
  if (!record) return { outcome: "not_found" };
  if (record.redeemedAt) return { outcome: "already_redeemed" };

  const hashMatches =
    record.manualCodeHash === hashCaregiverRedemptionCode(code.trim());
  const decision = evaluateCodeAttempt({
    pending: {
      expiresAtMs: new Date(record.expiresAt).getTime(),
      attempts: record.manualCodeAttempts,
    },
    hashMatches,
    nowMs: now.getTime(),
  });
  switch (decision.outcome) {
    case "expired":
      return { outcome: "expired" };
    case "locked":
      return { outcome: "locked" };
    case "missing":
      return { outcome: "not_found" };
    case "mismatch":
      await backend.incrementManualAttempts(record.id);
      return { outcome: "mismatch" };
    case "match": {
      const redeemedAtIso = now.toISOString();
      const won = await backend.markRedeemed(record.id, redeemedAtIso);
      if (!won) return { outcome: "already_redeemed" };
      return {
        outcome: "redeemed",
        record: { ...record, redeemedAt: redeemedAtIso },
      };
    }
  }
}
