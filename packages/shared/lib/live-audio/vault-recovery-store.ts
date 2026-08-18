import { createHash } from "node:crypto";

import { decodeVaultRecoverySecret } from "@/lib/live-audio/vault-recovery-secret";
import type { Reflection } from "@/types/journal";

/** Vault recovery eligibility outlives the live WS session ticket. */
export const VAULT_RECOVERY_TTL_MS = 1000 * 60 * 60 * 24 * 7;

export interface VaultRecoverySessionRecord {
  sessionId: string;
  subject: string;
  vaultRecoverySecretBase64: string;
  createdAt: number;
  expiresAt: number;
}

export interface VaultRecoveryAckRecord {
  sessionId: string;
  idempotencyKey: string;
  recoveryAckId: string;
  transcript: string;
  reflection: Reflection;
  durationSeconds: number;
  completedAt: number;
}

const globalStore = globalThis as typeof globalThis & {
  __vmLiveAudioVaultRecoverySessions?: Map<string, VaultRecoverySessionRecord>;
  __vmLiveAudioVaultRecoveryAcks?: Map<string, VaultRecoveryAckRecord>;
};

function sessions(): Map<string, VaultRecoverySessionRecord> {
  if (!globalStore.__vmLiveAudioVaultRecoverySessions) {
    globalStore.__vmLiveAudioVaultRecoverySessions = new Map();
  }
  return globalStore.__vmLiveAudioVaultRecoverySessions;
}

function acks(): Map<string, VaultRecoveryAckRecord> {
  if (!globalStore.__vmLiveAudioVaultRecoveryAcks) {
    globalStore.__vmLiveAudioVaultRecoveryAcks = new Map();
  }
  return globalStore.__vmLiveAudioVaultRecoveryAcks;
}

export function registerVaultRecoverySession(input: {
  sessionId: string;
  subject: string;
  vaultRecoverySecretBase64: string;
}): VaultRecoverySessionRecord {
  const secret = decodeVaultRecoverySecret(input.vaultRecoverySecretBase64);
  if (!secret) {
    throw new Error("Invalid vault recovery secret.");
  }
  const createdAt = Date.now();
  const record: VaultRecoverySessionRecord = {
    sessionId: input.sessionId,
    subject: input.subject,
    vaultRecoverySecretBase64: input.vaultRecoverySecretBase64,
    createdAt,
    expiresAt: createdAt + VAULT_RECOVERY_TTL_MS,
  };
  sessions().set(input.sessionId, record);
  return record;
}

export function lookupVaultRecoverySession(
  sessionId: string,
  subject: string,
):
  | { ok: true; record: VaultRecoverySessionRecord; secret: Buffer }
  | { ok: false; reason: "missing" | "expired" | "subject_mismatch" } {
  const record = sessions().get(sessionId);
  if (!record) return { ok: false, reason: "missing" };
  if (record.subject !== subject) return { ok: false, reason: "subject_mismatch" };
  if (Date.now() > record.expiresAt) return { ok: false, reason: "expired" };
  const secret = decodeVaultRecoverySecret(record.vaultRecoverySecretBase64);
  if (!secret) return { ok: false, reason: "missing" };
  return { ok: true, record, secret };
}

export function vaultRecoveryAckKey(sessionId: string, idempotencyKey: string): string {
  return `${sessionId}:${idempotencyKey}`;
}

export function lookupVaultRecoveryAck(
  sessionId: string,
  idempotencyKey: string,
): VaultRecoveryAckRecord | null {
  return acks().get(vaultRecoveryAckKey(sessionId, idempotencyKey)) ?? null;
}

export function recordVaultRecoveryAck(input: {
  sessionId: string;
  idempotencyKey: string;
  recoveryAckId: string;
  transcript: string;
  reflection: Reflection;
  durationSeconds: number;
}): VaultRecoveryAckRecord {
  const record: VaultRecoveryAckRecord = {
    sessionId: input.sessionId,
    idempotencyKey: input.idempotencyKey,
    recoveryAckId: input.recoveryAckId,
    transcript: input.transcript,
    reflection: input.reflection,
    durationSeconds: input.durationSeconds,
    completedAt: Date.now(),
  };
  acks().set(vaultRecoveryAckKey(input.sessionId, input.idempotencyKey), record);
  return record;
}

export function hashVaultBytes(bytes: Buffer): string {
  return createHash("sha256").update(bytes).digest("hex");
}

export function resetVaultRecoveryStoreForTest(): void {
  sessions().clear();
  acks().clear();
}
