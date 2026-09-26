import assert from "node:assert/strict";
import test from "node:test";

import {
  FREE_QUOTA_BYTES,
  QUOTA_MESSAGE,
  RATE_LIMIT_PER_MINUTE,
  RATE_MESSAGE,
  SyncRecordLedger,
  dropAccountSyncState,
  presignBlobPut,
  syncRecordLedger,
} from "../../../packages/shared/lib/server/sync-records.ts";

const record = {
  recordId: "river",
  kind: "entry" as const,
  version: 1,
  updatedAt: "2026-03-12T09:00:00.000Z",
  deviceId: "iphone-a",
  ciphertext: "c2VhbGVk",
  nonce: "bm9uY2U",
  keyVersion: 1,
  byteLength: 12,
};

test("record push rejects a transcript field and a full quota", () => {
  const ledger = new SyncRecordLedger();
  const leaked = ledger.push([{ ...record, transcript: "the river was high" } as never]);
  assert.equal(leaked.ok, false);
  if (!leaked.ok) assert.equal(leaked.error, "PLAINTEXT_NOT_ACCEPTED");

  const full = new SyncRecordLedger();
  full.bytes = FREE_QUOTA_BYTES - 4;
  const overflow = full.push([{ ...record, byteLength: 8 }]);
  assert.equal(overflow.ok, false);
  if (!overflow.ok) assert.equal(overflow.error, QUOTA_MESSAGE);

  const saved = ledger.push([record]);
  assert.equal(saved.ok, true);
  if (saved.ok) assert.equal(saved.cursor, 1);
  const pulled = ledger.pull(0);
  assert.equal(pulled.records.length, 1);
  assert.equal(JSON.stringify(pulled).includes("the river was high"), false);
});

test("tombstones older than 180 days drop out of a pull", () => {
  const ledger = new SyncRecordLedger();
  const deletedAt = new Date("2025-01-01T00:00:00.000Z");
  ledger.push([
    {
      ...record,
      recordId: "old",
      kind: "tombstone",
      updatedAt: deletedAt.toISOString(),
    },
  ]);
  const later = new Date(deletedAt.getTime() + 181 * 24 * 60 * 60 * 1000);
  assert.equal(ledger.pull(0, later).records.length, 0);
});

test("sync pushes are rate limited and media chunks stay at 4 MB", () => {
  const ledger = new SyncRecordLedger();
  const now = new Date("2026-09-26T12:00:00.000Z");
  for (let i = 0; i < RATE_LIMIT_PER_MINUTE; i += 1) {
    const result = ledger.push([{ ...record, recordId: `r${i}` }], now);
    assert.equal(result.ok, true);
  }
  const blocked = ledger.push([{ ...record, recordId: "extra" }], now);
  assert.equal(blocked.ok, false);
  if (!blocked.ok) assert.equal(blocked.error, RATE_MESSAGE);

  const tooBig = presignBlobPut({
    userId: "user",
    byteLength: 4 * 1024 * 1024 + 1,
    blobId: "chunk",
  });
  assert.equal(tooBig.ok, false);
  const signed = presignBlobPut({
    userId: "user",
    byteLength: 1024,
    blobId: "chunk",
  });
  assert.equal(signed.ok, true);
  if (signed.ok) assert.equal(signed.method, "PUT");
});

test("purge drops encrypted records, media chunks, and devices for one account", () => {
  const userId = "purge-account";
  syncRecordLedger(userId).push([record]);
  syncRecordLedger(userId).revokeDevice("iphone-b");
  const signed = presignBlobPut({
    userId,
    byteLength: 128,
    blobId: "chunk-1",
  });
  assert.equal(signed.ok, true);

  const dropped = dropAccountSyncState(userId);
  assert.equal(dropped.records, 1);
  assert.equal(dropped.mediaChunks, 1);
  assert.equal(dropped.devices, 2);
  assert.equal(syncRecordLedger(userId).storedCount(), 0);
  assert.equal(dropAccountSyncState(userId).mediaChunks, 0);
});
