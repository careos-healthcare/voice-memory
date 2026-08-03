import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  decideSyncRecoveryUpsert,
  parseSyncRecoveryEnvelope,
  type SyncRecoveryEnvelopeRecord,
} from "../lib/sync/recovery-envelope-contract";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function envelope(revision: number): SyncRecoveryEnvelopeRecord {
  return {
    schemaVersion: 1,
    kdf: "PBKDF2-HMAC-SHA256",
    kdfIterations: 310000,
    algorithm: "AES-256-GCM",
    ownerAccountId: "user-a",
    ownerArchiveId: "account_archive-a",
    keyEpoch: 1,
    envelopeRevision: revision,
    salt: "AAAAAAAAAAAAAAAAAAAAAA==",
    nonce: "AAAAAAAAAAAAAAAA",
    ciphertext: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
    mac: "AAAAAAAAAAAAAAAAAAAAAA==",
    createdAt: "2026-08-03T00:00:00.000Z",
    updatedAt: `2026-08-03T00:00:0${revision}.000Z`,
  };
}

test("recovery envelope writes are idempotent and reject replay", () => {
  assert.equal(
    decideSyncRecoveryUpsert(null, { envelopeRevision: 1, digest: "a" }),
    "created",
  );
  assert.equal(
    decideSyncRecoveryUpsert(
      { envelopeRevision: 1, digest: "a" },
      { envelopeRevision: 1, digest: "a" },
    ),
    "unchanged",
  );
  assert.equal(
    decideSyncRecoveryUpsert(
      { envelopeRevision: 1, digest: "a" },
      { envelopeRevision: 2, digest: "b" },
    ),
    "updated",
  );
  assert.throws(
    () =>
      decideSyncRecoveryUpsert(
        { envelopeRevision: 2, digest: "b" },
        { envelopeRevision: 1, digest: "a" },
      ),
    /STALE_RECOVERY_ENVELOPE/,
  );
});

test("conflicting same revision is rejected", () => {
  assert.throws(
    () =>
      decideSyncRecoveryUpsert(
        { envelopeRevision: 1, digest: "a" },
        { envelopeRevision: 1, digest: "b" },
      ),
    /RECOVERY_REVISION_CONFLICT/,
  );
});

test("account deletion registry owns recovery envelope cleanup", () => {
  const source = fs.readFileSync(
    path.join(
      root,
      "lib/server/privacy/user-data-deletion-registry.ts",
    ),
    "utf8",
  );
  assert.match(source, /sync-recovery-envelope/);
  assert.match(source, /sync_recovery_envelopes/);
});

test("backend rejects cross-account, schema, epoch, and unknown fields", () => {
  assert.ok(parseSyncRecoveryEnvelope(envelope(1), "user-a"));
  assert.equal(parseSyncRecoveryEnvelope(envelope(1), "user-b"), null);
  assert.equal(
    parseSyncRecoveryEnvelope({ ...envelope(1), schemaVersion: 2 }, "user-a"),
    null,
  );
  assert.equal(
    parseSyncRecoveryEnvelope({ ...envelope(1), keyEpoch: 2 }, "user-a"),
    null,
  );
  assert.equal(
    parseSyncRecoveryEnvelope({ ...envelope(1), plaintextKey: "leak" }, "user-a"),
    null,
  );
});

test("route source does not log or meter recovery payload fields", () => {
  const source = fs.readFileSync(
    path.join(root, "app/api/sync/recovery/route.ts"),
    "utf8",
  );
  assert.doesNotMatch(source, /console\.(?:log|warn|error)/);
  assert.doesNotMatch(source, /analytics|meterBestEffort|crash/i);
  assert.doesNotMatch(source, /recoverySecret|plaintextKey/);
});
