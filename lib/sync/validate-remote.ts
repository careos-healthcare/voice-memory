import type { EncryptedPayload, SyncManifest } from "@/types/sync";
import type { SyncErrorCode } from "@/types/sync-errors";

export interface RemoteValidationIssue {
  code: SyncErrorCode;
  detail: string;
  field?: string;
}

export interface RemoteValidationResult {
  valid: boolean;
  issues: RemoteValidationIssue[];
}

const BASE64_RE = /^[A-Za-z0-9+/]+=*$/;

function isValidIsoTimestamp(value: string | undefined): boolean {
  if (!value?.trim()) return false;
  const time = new Date(value).getTime();
  return Number.isFinite(time);
}

export function validateEncryptedEnvelope(
  payload: EncryptedPayload | null | undefined,
): RemoteValidationResult {
  const issues: RemoteValidationIssue[] = [];

  if (!payload) {
    issues.push({
      code: "EMPTY_REMOTE_PAYLOAD",
      detail: "Encrypted envelope is missing.",
    });
    return { valid: false, issues };
  }

  if (payload.version !== 1) {
    issues.push({
      code: "UNSUPPORTED_ENCRYPTION_VERSION",
      detail: `Unsupported encryption version: ${String(payload.version)}`,
      field: "version",
    });
  }

  if (!payload.iv?.trim()) {
    issues.push({
      code: "INVALID_ENCRYPTED_ENVELOPE",
      detail: "Initialization vector is missing.",
      field: "iv",
    });
  } else if (!BASE64_RE.test(payload.iv.trim()) || payload.iv.length < 8) {
    issues.push({
      code: "INVALID_ENCRYPTED_ENVELOPE",
      detail: "Initialization vector is malformed.",
      field: "iv",
    });
  }

  if (!payload.ciphertext?.trim()) {
    issues.push({
      code: "EMPTY_REMOTE_PAYLOAD",
      detail: "Ciphertext is empty.",
      field: "ciphertext",
    });
  } else if (!BASE64_RE.test(payload.ciphertext.trim()) || payload.ciphertext.length < 8) {
    issues.push({
      code: "INVALID_ENCRYPTED_ENVELOPE",
      detail: "Ciphertext is malformed.",
      field: "ciphertext",
    });
  }

  return { valid: issues.length === 0, issues };
}

export function validateRemoteManifest(manifest: SyncManifest | null | undefined): RemoteValidationResult {
  const issues: RemoteValidationIssue[] = [];

  if (!manifest) {
    issues.push({ code: "NO_REMOTE_BACKUP", detail: "Manifest is missing." });
    return { valid: false, issues };
  }

  if (!manifest.userId?.trim()) {
    issues.push({
      code: "INVALID_REMOTE_JSON",
      detail: "Manifest user id is missing.",
      field: "userId",
    });
  }

  if (!Number.isFinite(manifest.version)) {
    issues.push({
      code: "INVALID_REMOTE_JSON",
      detail: "Manifest version is invalid.",
      field: "version",
    });
  }

  if (!isValidIsoTimestamp(manifest.updatedAt)) {
    issues.push({
      code: "INVALID_REMOTE_JSON",
      detail: "Manifest timestamp is invalid.",
      field: "updatedAt",
    });
  }

  if (!Array.isArray(manifest.blobs)) {
    issues.push({
      code: "INVALID_REMOTE_JSON",
      detail: "Manifest blobs must be an array.",
      field: "blobs",
    });
  } else {
    for (const blob of manifest.blobs) {
      if (!blob.id?.trim()) {
        issues.push({
          code: "INVALID_REMOTE_JSON",
          detail: "Manifest blob id is missing.",
        });
      }
      if (!isValidIsoTimestamp(blob.updatedAt)) {
        issues.push({
          code: "INVALID_REMOTE_JSON",
          detail: `Manifest blob ${blob.id} has invalid timestamp.`,
        });
      }
    }
  }

  return { valid: issues.length === 0, issues };
}

export function validateRemoteBlobRecord(blob: {
  id?: string;
  encrypted?: EncryptedPayload;
  updatedAt?: string;
}): RemoteValidationResult {
  const issues: RemoteValidationIssue[] = [];

  if (!blob.id?.trim()) {
    issues.push({ code: "INVALID_REMOTE_JSON", detail: "Blob id is missing." });
  }

  if (!isValidIsoTimestamp(blob.updatedAt)) {
    issues.push({ code: "INVALID_REMOTE_JSON", detail: "Blob timestamp is invalid." });
  }

  const envelope = validateEncryptedEnvelope(blob.encrypted);
  issues.push(...envelope.issues);

  return { valid: issues.length === 0, issues };
}
