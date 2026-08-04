import { createHash } from "node:crypto";

const globalStore = globalThis as typeof globalThis & {
  __vmLiveAudioVaultChunkAcks?: Map<string, VaultChunkAckRecord>;
};

export interface VaultChunkAckRecord {
  sessionId: string;
  chunkId: string;
  idempotencyKey: string;
  byteLength: number;
  receivedAt: number;
}

function acks(): Map<string, VaultChunkAckRecord> {
  if (!globalStore.__vmLiveAudioVaultChunkAcks) {
    globalStore.__vmLiveAudioVaultChunkAcks = new Map();
  }
  return globalStore.__vmLiveAudioVaultChunkAcks;
}

export function recordVaultChunkUpload(input: {
  sessionId: string;
  chunkId: string;
  idempotencyKey: string;
  audioBytes: Buffer;
}): { chunkAckId: string; duplicate: boolean } {
  const existing = acks().get(input.idempotencyKey);
  if (existing) {
    return { chunkAckId: existing.chunkId, duplicate: true };
  }

  const chunkAckId =
    input.chunkId ||
    createHash("sha256")
      .update(`${input.sessionId}:${input.idempotencyKey}:${input.audioBytes.length}`)
      .digest("hex")
      .slice(0, 24);

  acks().set(input.idempotencyKey, {
    sessionId: input.sessionId,
    chunkId: chunkAckId,
    idempotencyKey: input.idempotencyKey,
    byteLength: input.audioBytes.length,
    receivedAt: Date.now(),
  });

  return { chunkAckId, duplicate: false };
}

export function resetVaultChunkStoreForTest(): void {
  globalStore.__vmLiveAudioVaultChunkAcks = new Map();
}
