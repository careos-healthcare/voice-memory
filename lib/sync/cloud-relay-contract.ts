import type { SyncBlobRecord } from "@/types/sync";
import { parseE2EERelayBlob } from "@/lib/sync/e2ee-relay-contract";

export const CLOUD_RELAY_RETENTION_MS = 30 * 24 * 60 * 60 * 1000;
export const CLOUD_RELAY_MAX_ENVELOPE_BYTES = 256 * 1024;
export const CLOUD_RELAY_MAX_BATCH_ENVELOPES = 32;
export const CLOUD_RELAY_MAX_BATCH_BYTES = 2 * 1024 * 1024;
export const CLOUD_RELAY_MAX_VAULT_BYTES = 32 * 1024 * 1024;

export interface CloudRelayPushRequest {
  action: "push";
  envelopes: SyncBlobRecord[];
}

export interface CloudRelayIssueTokenRequest {
  action: "issue_token";
  deviceId: string;
}

const DEVICE_ID = /^[A-Za-z0-9_.:-]{1,128}$/;

function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Request body must be an object.");
  }
  return value as Record<string, unknown>;
}

export function parseCloudRelayIssueTokenRequest(
  value: unknown,
): CloudRelayIssueTokenRequest {
  const body = object(value);
  if (
    Object.keys(body).some((key) => !["action", "deviceId"].includes(key)) ||
    body.action !== "issue_token" ||
    typeof body.deviceId !== "string" ||
    !DEVICE_ID.test(body.deviceId)
  ) {
    throw new Error("Invalid relay token request.");
  }
  return { action: "issue_token", deviceId: body.deviceId };
}

export function parseCloudRelayPushRequest(
  value: unknown,
): CloudRelayPushRequest {
  const body = object(value);
  if (
    Object.keys(body).some((key) => !["action", "envelopes"].includes(key)) ||
    body.action !== "push" ||
    !Array.isArray(body.envelopes) ||
    body.envelopes.length === 0 ||
    body.envelopes.length > CLOUD_RELAY_MAX_BATCH_ENVELOPES
  ) {
    throw new Error("Invalid relay push request.");
  }
  const ids = new Set<string>();
  let totalBytes = 0;
  const envelopes = body.envelopes.map((value) => {
    const envelope = parseE2EERelayBlob(value);
    if (!ids.add(envelope.id)) throw new Error("Duplicate relay envelope id.");
    const ciphertextBytes = Buffer.from(
      envelope.encrypted.ciphertext,
      "base64",
    ).byteLength;
    const ivBytes = Buffer.from(envelope.encrypted.iv, "base64").byteLength;
    const opaqueBytes = ciphertextBytes + ivBytes;
    if (
      ivBytes !== 12 ||
      ciphertextBytes <= 16 ||
      opaqueBytes > CLOUD_RELAY_MAX_ENVELOPE_BYTES
    ) {
      throw new Error("Relay envelope exceeds opaque storage limits.");
    }
    totalBytes += opaqueBytes;
    return { ...envelope, byteLength: opaqueBytes };
  });
  if (totalBytes > CLOUD_RELAY_MAX_BATCH_BYTES) {
    throw new Error("Relay batch exceeds opaque storage limits.");
  }
  return { action: "push", envelopes };
}

export function cloudRelaySecurityHeaders(): Record<string, string> {
  return {
    "Cache-Control": "no-store, private, max-age=0",
    Pragma: "no-cache",
    Expires: "0",
    "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
    "X-Robots-Tag": "noindex, nofollow, noarchive",
    "X-ArchiveMe-Zero-Knowledge": "true",
    "X-ArchiveMe-Relay-Retention": "opaque-only; max-age=2592000",
    "X-ArchiveMe-Telemetry": "disabled",
  };
}
