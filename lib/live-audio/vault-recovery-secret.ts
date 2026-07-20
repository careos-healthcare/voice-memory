import { randomBytes } from "node:crypto";

/** 256-bit AES key material for recoverable offline live-audio vaults. */
export const VAULT_RECOVERY_SECRET_BYTES = 32;

export function createVaultRecoverySecret(): string {
  return randomBytes(VAULT_RECOVERY_SECRET_BYTES).toString("base64url");
}

export function decodeVaultRecoverySecret(encoded: string): Buffer | null {
  try {
    const bytes = Buffer.from(encoded, "base64url");
    if (bytes.length !== VAULT_RECOVERY_SECRET_BYTES) return null;
    return bytes;
  } catch {
    return null;
  }
}

/** Accepts base64url, base64, or hex-encoded 32-byte recovery key material. */
export function decodeVaultRecoverySecretField(raw: string): Buffer | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;

  const base64Url = decodeVaultRecoverySecret(trimmed);
  if (base64Url) return base64Url;

  try {
    const standardBase64 = Buffer.from(trimmed, "base64");
    if (standardBase64.length === VAULT_RECOVERY_SECRET_BYTES) {
      return standardBase64;
    }
  } catch {
    // fall through
  }

  if (/^[0-9a-fA-F]{64}$/.test(trimmed)) {
    return Buffer.from(trimmed, "hex");
  }

  return null;
}
