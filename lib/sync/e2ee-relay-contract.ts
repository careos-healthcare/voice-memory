import type { EncryptedPayload, SyncBlobRecord } from "@/types/sync";

const DEVICE_ID = /^[A-Za-z0-9_.:-]{1,128}$/;
const BLOB_ID = /^[A-Za-z0-9_.:-]{1,192}$/;
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;
const FORBIDDEN = new Set([
  "transcript",
  "entries",
  "text",
  "plaintext",
  "content",
  "nodes",
  "edges",
]);

function object(value: unknown, name: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${name} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function encryptedPayload(value: unknown): EncryptedPayload {
  const payload = object(value, "encrypted");
  if (
    Object.keys(payload).some(
      (key) => !["ciphertext", "iv", "version"].includes(key),
    )
  ) {
    throw new Error("Encrypted payload contains an unexpected field.");
  }
  if (
    payload.version !== 1 ||
    typeof payload.ciphertext !== "string" ||
    !BASE64.test(payload.ciphertext) ||
    typeof payload.iv !== "string" ||
    !BASE64.test(payload.iv)
  ) {
    throw new Error("Invalid encrypted payload.");
  }
  return {
    ciphertext: payload.ciphertext,
    iv: payload.iv,
    version: 1,
  };
}

export function parseE2EERelayBlob(value: unknown): SyncBlobRecord {
  const blob = object(value, "blob");
  for (const key of Object.keys(blob)) {
    if (FORBIDDEN.has(key)) {
      throw new Error(`Plaintext field rejected: ${key}`);
    }
  }
  if (blob.type !== "crdt_operations") {
    throw new Error("E2EE relay only accepts CRDT operation blobs.");
  }
  if (typeof blob.id !== "string" || !BLOB_ID.test(blob.id)) {
    throw new Error("Invalid relay blob id.");
  }
  if (typeof blob.deviceId !== "string" || !DEVICE_ID.test(blob.deviceId)) {
    throw new Error("Invalid relay device id.");
  }
  const vectorClockRaw = object(blob.vectorClock, "vectorClock");
  const vectorClock: Record<string, number> = {};
  for (const [deviceId, counter] of Object.entries(vectorClockRaw)) {
    if (
      !DEVICE_ID.test(deviceId) ||
      typeof counter !== "number" ||
      !Number.isSafeInteger(counter) ||
      counter < 0
    ) {
      throw new Error("Invalid vector clock.");
    }
    vectorClock[deviceId] = counter;
  }
  if (Object.keys(vectorClock).length === 0) {
    throw new Error("Vector clock cannot be empty.");
  }
  if (
    typeof blob.updatedAt !== "string" ||
    Number.isNaN(Date.parse(blob.updatedAt))
  ) {
    throw new Error("Invalid relay timestamp.");
  }
  if (
    typeof blob.byteLength !== "number" ||
    !Number.isSafeInteger(blob.byteLength) ||
    blob.byteLength <= 0
  ) {
    throw new Error("Invalid encrypted payload size.");
  }
  const keyEpoch =
    typeof blob.keyEpoch === "number" && Number.isSafeInteger(blob.keyEpoch)
      ? blob.keyEpoch
      : 1;
  if (keyEpoch < 1) throw new Error("Invalid key epoch.");

  return {
    id: blob.id,
    type: "crdt_operations",
    encrypted: encryptedPayload(blob.encrypted),
    updatedAt: blob.updatedAt,
    byteLength: blob.byteLength,
    deviceId: blob.deviceId,
    vectorClock,
    keyEpoch,
  };
}
