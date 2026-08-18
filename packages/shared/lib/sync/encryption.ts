import { SyncEncryptionError } from "@/lib/sync/sync-errors";
import { validateEncryptedEnvelope } from "@/lib/sync/validate-remote";
import type { EncryptedPayload } from "@/types/sync";

const SYNC_KEY_STORAGE = "voicememory_sync_master_key";
const SYNC_META_STORAGE = "voicememory_sync_key_meta";

interface SyncKeyMeta {
  createdAt: string;
  version: 1;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function base64ToBytes(value: string): Uint8Array {
  try {
    const binary = atob(value.trim());
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
    return bytes;
  } catch {
    throw new SyncEncryptionError("INVALID_ENCRYPTED_ENVELOPE", "Ciphertext is malformed.");
  }
}

function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  return copy.buffer;
}

function assertValidEnvelope(payload: EncryptedPayload): void {
  const validation = validateEncryptedEnvelope(payload);
  if (!validation.valid) {
    const primary = validation.issues[0];
    throw new SyncEncryptionError(
      primary?.code ?? "INVALID_ENCRYPTED_ENVELOPE",
      primary?.detail ?? "Encrypted envelope is invalid.",
    );
  }
}

async function importRawKey(raw: Uint8Array): Promise<CryptoKey> {
  return crypto.subtle.importKey("raw", toArrayBuffer(raw), { name: "AES-GCM" }, false, [
    "encrypt",
    "decrypt",
  ]);
}

async function generateRawKey(): Promise<Uint8Array> {
  const key = await crypto.subtle.generateKey({ name: "AES-GCM", length: 256 }, true, [
    "encrypt",
    "decrypt",
  ]);
  const exported = await crypto.subtle.exportKey("raw", key);
  return new Uint8Array(exported);
}

/** Device-local sync master key — never sent to server in plaintext. */
export async function ensureSyncMasterKey(): Promise<CryptoKey> {
  if (!isBrowser()) throw new Error("Sync encryption is browser-only.");

  const existing = localStorage.getItem(SYNC_KEY_STORAGE);
  if (existing) {
    return importRawKey(base64ToBytes(existing));
  }

  const raw = await generateRawKey();
  localStorage.setItem(SYNC_KEY_STORAGE, bytesToBase64(raw));
  localStorage.setItem(
    SYNC_META_STORAGE,
    JSON.stringify({ createdAt: new Date().toISOString(), version: 1 } satisfies SyncKeyMeta),
  );
  return importRawKey(raw);
}

export function hasSyncMasterKey(): boolean {
  if (!isBrowser()) return false;
  return Boolean(localStorage.getItem(SYNC_KEY_STORAGE));
}

export async function encryptJsonPayload(value: unknown): Promise<EncryptedPayload> {
  const key = await ensureSyncMasterKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encoded = new TextEncoder().encode(JSON.stringify(value));
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: toArrayBuffer(iv) },
    key,
    encoded,
  );

  return {
    version: 1,
    iv: bytesToBase64(iv),
    ciphertext: bytesToBase64(new Uint8Array(ciphertext)),
  };
}

export async function decryptJsonPayload<T>(payload: EncryptedPayload): Promise<T> {
  assertValidEnvelope(payload);

  try {
    const key = await ensureSyncMasterKey();
    const iv = base64ToBytes(payload.iv);
    const ciphertext = base64ToBytes(payload.ciphertext);
    const decrypted = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: toArrayBuffer(iv) },
      key,
      toArrayBuffer(ciphertext),
    );
    const text = new TextDecoder().decode(decrypted);
    if (!text.trim()) {
      throw new SyncEncryptionError("EMPTY_REMOTE_PAYLOAD", "Decrypted backup payload is empty.");
    }
    try {
      return JSON.parse(text) as T;
    } catch {
      throw new SyncEncryptionError("INVALID_REMOTE_JSON", "Decrypted backup JSON is invalid.");
    }
  } catch (error) {
    if (error instanceof SyncEncryptionError) throw error;
    throw new SyncEncryptionError("DECRYPT_FAILED", "Encrypted backup could not be verified.");
  }
}

export async function encryptBinaryPayload(data: ArrayBuffer): Promise<EncryptedPayload> {
  const key = await ensureSyncMasterKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: toArrayBuffer(iv) },
    key,
    data,
  );

  return {
    version: 1,
    iv: bytesToBase64(iv),
    ciphertext: bytesToBase64(new Uint8Array(ciphertext)),
  };
}

export async function decryptBinaryPayload(payload: EncryptedPayload): Promise<ArrayBuffer> {
  assertValidEnvelope(payload);

  try {
    const key = await ensureSyncMasterKey();
    const iv = base64ToBytes(payload.iv);
    const ciphertext = base64ToBytes(payload.ciphertext);
    return crypto.subtle.decrypt(
      { name: "AES-GCM", iv: toArrayBuffer(iv) },
      key,
      toArrayBuffer(ciphertext),
    );
  } catch (error) {
    if (error instanceof SyncEncryptionError) throw error;
    throw new SyncEncryptionError("DECRYPT_FAILED", "Encrypted backup could not be verified.");
  }
}

export function clearSyncMasterKey(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(SYNC_KEY_STORAGE);
  localStorage.removeItem(SYNC_META_STORAGE);
}
