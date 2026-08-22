import type { SyncErrorCode } from "@/types/sync-errors";

export class SyncClientError extends Error {
  code: SyncErrorCode;

  constructor(code: SyncErrorCode, message: string) {
    super(message);
    this.name = "SyncClientError";
    this.code = code;
  }
}

export class SyncEncryptionError extends Error {
  code: SyncErrorCode;

  constructor(code: SyncErrorCode, message: string) {
    super(message);
    this.name = "SyncEncryptionError";
    this.code = code;
  }
}

const JSON_PARSE_RE = /JSON\.parse|unexpected end of data|Unexpected end of JSON input/i;

export function mapSyncErrorToUserMessage(error: unknown): string {
  if (error instanceof SyncClientError || error instanceof SyncEncryptionError) {
    switch (error.code) {
      case "EMPTY_REMOTE_PAYLOAD":
      case "INVALID_REMOTE_JSON":
      case "NON_JSON_RESPONSE":
        return "Remote backup response was invalid.";
      case "INVALID_ENCRYPTED_ENVELOPE":
      case "DECRYPT_FAILED":
      case "UNSUPPORTED_ENCRYPTION_VERSION":
      case "REMOTE_BACKUP_CORRUPT":
        return "Encrypted backup could not be verified.";
      case "NO_REMOTE_BACKUP":
        return "No backup found yet.";
      case "SYNC_AUTH_REQUIRED":
        return "Sign in to sync your archive.";
      case "SYNC_PUSH_FAILED":
        return "Encrypted backup could not be saved.";
      case "SYNC_PULL_FAILED":
      case "SYNC_MANIFEST_FAILED":
        return "Remote backup response was invalid.";
      default:
        return error.message;
    }
  }

  if (error instanceof Error) {
    if (JSON_PARSE_RE.test(error.message)) {
      return "Remote backup response was invalid.";
    }
    if (/decrypt|encrypted backup could not/i.test(error.message)) {
      return "Encrypted backup could not be verified.";
    }
    if (/no backup|no encrypted archive/i.test(error.message)) {
      return "No backup found yet.";
    }
    if (/Encrypted backup failed/i.test(error.message)) {
      return "Encrypted backup could not be saved.";
    }
    return error.message;
  }

  return "Sync failed.";
}

export function toSyncClientError(error: unknown, fallbackCode: SyncErrorCode): SyncClientError {
  if (error instanceof SyncClientError || error instanceof SyncEncryptionError) {
    return new SyncClientError(error.code, mapSyncErrorToUserMessage(error));
  }
  if (error instanceof Error && JSON_PARSE_RE.test(error.message)) {
    return new SyncClientError("INVALID_REMOTE_JSON", mapSyncErrorToUserMessage(error));
  }
  return new SyncClientError(fallbackCode, mapSyncErrorToUserMessage(error));
}
