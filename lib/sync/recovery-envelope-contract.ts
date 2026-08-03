export interface SyncRecoveryEnvelopeRecord {
  schemaVersion: 1;
  kdf: "PBKDF2-HMAC-SHA256";
  kdfIterations: 310000;
  algorithm: "AES-256-GCM";
  ownerAccountId: string;
  ownerArchiveId: string;
  keyEpoch: number;
  envelopeRevision: number;
  salt: string;
  nonce: string;
  ciphertext: string;
  mac: string;
  createdAt: string;
  updatedAt: string;
}

export function decideSyncRecoveryUpsert(
  current: { envelopeRevision: number; digest: string } | null,
  next: { envelopeRevision: number; digest: string },
): "created" | "updated" | "unchanged" {
  if (!current) return "created";
  if (next.envelopeRevision < current.envelopeRevision) {
    throw new Error("STALE_RECOVERY_ENVELOPE");
  }
  if (next.envelopeRevision === current.envelopeRevision) {
    if (next.digest === current.digest) return "unchanged";
    throw new Error("RECOVERY_REVISION_CONFLICT");
  }
  return "updated";
}

function isBase64Url(value: unknown, decodedBytes: number): value is string {
  if (
    typeof value !== "string" ||
    !/^[A-Za-z0-9_-]+={0,2}$/.test(value)
  ) {
    return false;
  }
  try {
    return Buffer.from(value, "base64url").byteLength === decodedBytes;
  } catch {
    return false;
  }
}

export function parseSyncRecoveryEnvelope(
  value: unknown,
  userId: string,
): SyncRecoveryEnvelopeRecord | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const item = value as Record<string, unknown>;
  const exactKeys = [
    "schemaVersion",
    "kdf",
    "kdfIterations",
    "algorithm",
    "ownerAccountId",
    "ownerArchiveId",
    "keyEpoch",
    "envelopeRevision",
    "salt",
    "nonce",
    "ciphertext",
    "mac",
    "createdAt",
    "updatedAt",
  ];
  if (
    Object.keys(item).length !== exactKeys.length ||
    exactKeys.some((key) => !(key in item))
  ) {
    return null;
  }
  if (
    item.schemaVersion !== 1 ||
    item.kdf !== "PBKDF2-HMAC-SHA256" ||
    item.kdfIterations !== 310000 ||
    item.algorithm !== "AES-256-GCM" ||
    item.ownerAccountId !== userId ||
    typeof item.ownerArchiveId !== "string" ||
    item.ownerArchiveId.length < 8 ||
    item.ownerArchiveId.length > 200 ||
    item.keyEpoch !== 1 ||
    !Number.isSafeInteger(item.envelopeRevision) ||
    (item.envelopeRevision as number) < 1 ||
    !isBase64Url(item.salt, 16) ||
    !isBase64Url(item.nonce, 12) ||
    !isBase64Url(item.ciphertext, 32) ||
    !isBase64Url(item.mac, 16) ||
    typeof item.createdAt !== "string" ||
    typeof item.updatedAt !== "string"
  ) {
    return null;
  }
  const created = Date.parse(item.createdAt);
  const updated = Date.parse(item.updatedAt);
  if (
    !Number.isFinite(created) ||
    !Number.isFinite(updated) ||
    updated < created
  ) {
    return null;
  }
  return item as unknown as SyncRecoveryEnvelopeRecord;
}
