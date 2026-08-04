import assert from "node:assert/strict";

import {
  pushCloudRelayEnvelopes,
  registerCloudRelayDevice,
  resetCloudRelayMemoryStoreForTests,
  takeCloudRelayEnvelopes,
} from "../server/cloud-relay-store";
import {
  mintCloudRelayToken,
  verifyCloudRelayToken,
} from "../sync/cloud-relay-auth";
import {
  CLOUD_RELAY_MAX_BATCH_ENVELOPES,
  cloudRelaySecurityHeaders,
  parseCloudRelayPushRequest,
} from "../sync/cloud-relay-contract";

function relayBlob(id: string, deviceId = "device-a") {
  const ciphertext = Buffer.alloc(48, id.length).toString("base64");
  const iv = Buffer.alloc(12, 7).toString("base64");
  return {
    id,
    type: "crdt_operations",
    deviceId,
    vectorClock: { [deviceId]: 1 },
    keyEpoch: 1,
    encrypted: { ciphertext, iv, version: 1 },
    updatedAt: "2026-07-28T08:00:00.000Z",
    byteLength: 999999,
  };
}

export async function runCloudRelayContractTests(): Promise<void> {
  const now = Date.UTC(2026, 6, 28, 8);
  const { token, access } = mintCloudRelayToken("user-a", "device-a", now);
  assert.deepEqual(verifyCloudRelayToken(token, now + 1000), access);
  assert.equal(verifyCloudRelayToken(`${token}tampered`, now + 1000), null);
  assert.equal(verifyCloudRelayToken(token, access.expiresAt), null);
  assert.notEqual(
    mintCloudRelayToken("user-b", "device-a", now).access.vaultHash,
    access.vaultHash,
  );

  const parsed = parseCloudRelayPushRequest({
    action: "push",
    envelopes: [relayBlob("envelope-a")],
  });
  assert.equal(parsed.envelopes.length, 1);
  assert.ok(parsed.envelopes[0]!.byteLength < 999999);
  assert.throws(
    () =>
      parseCloudRelayPushRequest({
        action: "push",
        envelopes: [
          {
            ...relayBlob("plaintext"),
            transcript: "private archive words",
          },
        ],
      }),
    /Plaintext field rejected/,
  );
  assert.throws(
    () =>
      parseCloudRelayPushRequest({
        action: "push",
        envelopes: Array.from(
          { length: CLOUD_RELAY_MAX_BATCH_ENVELOPES + 1 },
          (_, index) => relayBlob(`overflow-${index}`),
        ),
      }),
    /Invalid relay push request/,
  );

  resetCloudRelayMemoryStoreForTests();
  await registerCloudRelayDevice(access.vaultHash, "device-a", new Date(now));
  await registerCloudRelayDevice(access.vaultHash, "device-b", new Date(now));
  await pushCloudRelayEnvelopes(
    access.vaultHash,
    "device-a",
    parsed.envelopes,
    new Date(now),
  );
  const retrieved = await takeCloudRelayEnvelopes(
    access.vaultHash,
    "device-b",
    new Date(now + 1000),
  );
  assert.equal(retrieved.length, 1);
  assert.equal(
    retrieved[0]!.encrypted.ciphertext,
    parsed.envelopes[0]!.encrypted.ciphertext,
  );
  assert.deepEqual(
    await takeCloudRelayEnvelopes(
      access.vaultHash,
      "device-b",
      new Date(now + 2000),
    ),
    [],
    "retrieved ciphertext must be consumed for that device",
  );

  await pushCloudRelayEnvelopes(
    access.vaultHash,
    "device-a",
    parseCloudRelayPushRequest({
      action: "push",
      envelopes: [relayBlob("expired")],
    }).envelopes,
    new Date(now),
  );
  assert.deepEqual(
    await takeCloudRelayEnvelopes(
      access.vaultHash,
      "device-b",
      new Date(now + 31 * 24 * 60 * 60 * 1000),
    ),
    [],
    "opaque ciphertext must expire after 30 days",
  );

  const headers = cloudRelaySecurityHeaders();
  assert.match(headers["Cache-Control"] ?? "", /no-store/);
  assert.equal(headers["X-ArchiveMe-Zero-Knowledge"], "true");
  assert.equal(headers["X-ArchiveMe-Telemetry"], "disabled");
}
