export const FREE_QUOTA_BYTES = 5 * 1024 * 1024 * 1024;
export const TOMBSTONE_MS = 180 * 24 * 60 * 60 * 1000;
export const PAIR_EXPIRY_MS = 5 * 60 * 1000;
export const RATE_LIMIT_PER_MINUTE = 60;
export const MEDIA_CHUNK_BYTES = 4 * 1024 * 1024;
export const QUOTA_MESSAGE = "Thoughtprint sync storage is full (5 GB).";
export const RATE_MESSAGE = "Too many sync attempts. Wait a minute and try again.";

const forbiddenKeys = ["transcript", "text", "plaintext", "audio"] as const;

export type SyncRecordKind = "entry" | "photo" | "audio" | "tombstone";

export type SyncRecordInput = {
  recordId: string;
  kind: SyncRecordKind;
  version: number;
  updatedAt: string;
  deviceId: string;
  ciphertext: string;
  nonce: string;
  keyVersion: number;
  byteLength: number;
};

type StoredRecord = SyncRecordInput & { cursor: number };

export type SyncPushResult =
  | { ok: true; cursor: number; records: StoredRecord[] }
  | { ok: false; status: number; error: string };

export class SyncRecordLedger {
  cursor = 0;
  bytes = 0;
  private readonly records = new Map<string, StoredRecord>();
  private readonly hits: number[] = [];
  private keys: {
    wrappedByPassphrase: unknown;
    wrappedByRecovery: unknown;
    kdfParams: unknown;
    createdAt: string;
  } | null = null;
  private readonly revokedDevices = new Set<string>();
  private readonly relays = new Map<
    string,
    { ciphertext: string; nonce: string; expiresAt: number; claimed: boolean }
  >();

  push(records: SyncRecordInput[], now = new Date()): SyncPushResult {
    const stamp = now.getTime();
    while (this.hits.length > 0 && stamp - this.hits[0] >= 60_000) this.hits.shift();
    if (this.hits.length >= RATE_LIMIT_PER_MINUTE) {
      return { ok: false, status: 429, error: RATE_MESSAGE };
    }
    if (records.some((record) => this.revokedDevices.has(record.deviceId))) {
      return { ok: false, status: 401, error: "This device was removed." };
    }
    for (const record of records) {
      const bag = record as unknown as Record<string, unknown>;
      if (forbiddenKeys.some((key) => bag[key] != null)) {
        return { ok: false, status: 400, error: "PLAINTEXT_NOT_ACCEPTED" };
      }
      if (!record.ciphertext || !record.nonce || !record.recordId) {
        return { ok: false, status: 400, error: "INVALID_ENCRYPTED_ENVELOPE" };
      }
    }
    const incoming = records.reduce((sum, row) => sum + Math.max(0, row.byteLength), 0);
    if (this.bytes + incoming > FREE_QUOTA_BYTES) {
      return { ok: false, status: 413, error: QUOTA_MESSAGE };
    }
    this.hits.push(stamp);
    const stored: StoredRecord[] = [];
    for (const record of records) {
      const previous = this.records.get(record.recordId);
      if (previous) this.bytes -= previous.byteLength;
      this.cursor += 1;
      this.bytes += record.byteLength;
      const row = { ...record, cursor: this.cursor };
      this.records.set(record.recordId, row);
      stored.push(row);
    }
    return { ok: true, cursor: this.cursor, records: stored };
  }

  pull(since: number, now = new Date()) {
    const rows = [...this.records.values()].filter((row) => {
      if (row.cursor <= since) return false;
      if (row.kind !== "tombstone") return true;
      return now.getTime() - Date.parse(row.updatedAt) < TOMBSTONE_MS;
    });
    return { records: rows, cursor: this.cursor };
  }

  putRelay(id: string, ciphertext: string, nonce: string, now = new Date()) {
    this.relays.set(id, {
      ciphertext,
      nonce,
      expiresAt: now.getTime() + PAIR_EXPIRY_MS,
      claimed: false,
    });
    return { id, expiresAt: new Date(now.getTime() + PAIR_EXPIRY_MS).toISOString() };
  }

  storeKeys(input: {
    wrappedByPassphrase: unknown;
    wrappedByRecovery: unknown;
    kdfParams: unknown;
    createdAt?: string;
  }) {
    this.keys = {
      wrappedByPassphrase: input.wrappedByPassphrase,
      wrappedByRecovery: input.wrappedByRecovery,
      kdfParams: input.kdfParams,
      createdAt: input.createdAt ?? new Date().toISOString(),
    };
    return this.keys;
  }

  readKeys() {
    return this.keys;
  }

  revokeDevice(deviceId: string) {
    this.revokedDevices.add(deviceId);
  }

  storedCount(): number {
    return this.records.size;
  }

  deviceCount(): number {
    const ids = new Set<string>();
    for (const row of this.records.values()) ids.add(row.deviceId);
    for (const id of this.revokedDevices) ids.add(id);
    return ids.size;
  }

  claimRelay(id: string, now = new Date()) {
    const relay = this.relays.get(id);
    if (!relay || relay.claimed || now.getTime() >= relay.expiresAt) {
      return { ok: false as const, error: "This device link has expired." };
    }
    relay.claimed = true;
    return { ok: true as const, ciphertext: relay.ciphertext, nonce: relay.nonce };
  }
}

const ledgers = new Map<string, SyncRecordLedger>();
const mediaChunkIds = new Map<string, Set<string>>();

export function syncRecordLedger(userId: string): SyncRecordLedger {
  const existing = ledgers.get(userId);
  if (existing) return existing;
  const created = new SyncRecordLedger();
  ledgers.set(userId, created);
  return created;
}

export function registerMediaChunk(userId: string, blobId: string): void {
  const accountId = userId.trim();
  const id = blobId.trim();
  if (!accountId || !id) return;
  const existing = mediaChunkIds.get(accountId) ?? new Set<string>();
  existing.add(id);
  mediaChunkIds.set(accountId, existing);
}

/** Drops the in-memory encrypted records, media chunk ids, and device list. */
export function dropAccountSyncState(userId: string): {
  records: number;
  mediaChunks: number;
  devices: number;
} {
  const accountId = userId.trim();
  const ledger = ledgers.get(accountId);
  const records = ledger?.storedCount() ?? 0;
  const devices = ledger?.deviceCount() ?? 0;
  ledgers.delete(accountId);
  const mediaChunks = mediaChunkIds.get(accountId)?.size ?? 0;
  mediaChunkIds.delete(accountId);
  return { records, mediaChunks, devices };
}

export function presignBlobPut(input: {
  userId: string;
  byteLength: number;
  blobId: string;
}) {
  if (input.byteLength > MEDIA_CHUNK_BYTES) {
    return { ok: false as const, status: 413, error: "Media chunks are 4 MB." };
  }
  registerMediaChunk(input.userId, input.blobId);
  return {
    ok: true as const,
    blobId: input.blobId,
    method: "PUT" as const,
    expiresInSeconds: 300,
    url: `https://blob.thoughtprint.invalid/${input.userId}/${input.blobId}`,
  };
}
