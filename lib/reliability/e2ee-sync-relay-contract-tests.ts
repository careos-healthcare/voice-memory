import assert from "node:assert/strict";

import { parseE2EERelayBlob } from "../sync/e2ee-relay-contract";

export async function runE2EESyncRelayContractTests(): Promise<void> {
  const valid = {
    id: "crdt-device-a-4",
    type: "crdt_operations",
    deviceId: "device-a",
    vectorClock: { "device-a": 4, "device-b": 2 },
    keyEpoch: 1,
    encrypted: {
      ciphertext: "YWJjZGVmZ2hpamtsbW5vcA==",
      iv: "YWJjZGVmZ2hpamts",
      version: 1,
    },
    updatedAt: "2026-07-27T05:00:00.000Z",
    byteLength: 24,
  };
  const parsed = parseE2EERelayBlob(valid);
  assert.equal(parsed.deviceId, "device-a");
  assert.deepEqual(parsed.vectorClock, { "device-a": 4, "device-b": 2 });
  assert.deepEqual(parsed.encrypted, valid.encrypted);

  assert.throws(
    () => parseE2EERelayBlob({ ...valid, transcript: "private words" }),
    /Plaintext field rejected/,
  );
  assert.throws(
    () =>
      parseE2EERelayBlob({
        ...valid,
        vectorClock: { "device-a": -1 },
      }),
    /Invalid vector clock/,
  );
  assert.throws(
    () =>
      parseE2EERelayBlob({
        ...valid,
        encrypted: { ...valid.encrypted, plaintext: "{}" },
      }),
    /unexpected field/,
  );

  // The contract returns ciphertext unchanged and has no plaintext parser.
  assert.equal(parsed.encrypted.ciphertext, valid.encrypted.ciphertext);
}
