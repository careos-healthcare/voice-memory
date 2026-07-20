import assert from "node:assert/strict";
import { createCipheriv, randomBytes } from "node:crypto";

import { parseReflectionResponse } from "@/lib/analyze/parse-reflection-response";
import {
  decryptVaultFile,
  parseVaultHeader,
  VAULT_FORMAT_VERSION,
  VAULT_MAGIC,
  wrapPcm16LeInWav,
} from "@/lib/live-audio/vault-format";
import {
  createVaultRecoverySecret,
  decodeVaultRecoverySecret,
  decodeVaultRecoverySecretField,
} from "@/lib/live-audio/vault-recovery-secret";
import {
  lookupVaultRecoveryAck,
  lookupVaultRecoverySession,
  recordVaultRecoveryAck,
  registerVaultRecoverySession,
  resetVaultRecoveryStoreForTest,
} from "@/lib/live-audio/vault-recovery-store";

function buildEncryptedVault(
  secret: Buffer,
  pcmFrame: Buffer,
): Buffer {
  const header = Buffer.alloc(10);
  VAULT_MAGIC.copy(header, 0);
  header[4] = VAULT_FORMAT_VERSION;
  header.writeUInt32LE(16000, 5);
  header[9] = 1;

  const nonce = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", secret, nonce);
  const encrypted = Buffer.concat([cipher.update(pcmFrame), cipher.final()]);
  const mac = cipher.getAuthTag();

  const record = Buffer.alloc(4 + 12 + 16 + encrypted.length);
  record.writeUInt32LE(encrypted.length, 0);
  nonce.copy(record, 4);
  mac.copy(record, 16);
  encrypted.copy(record, 32);
  return Buffer.concat([header, record]);
}

export async function runLiveAudioVaultRecoveryRouteTests(): Promise<{
  failures: string[];
}> {
  const failures: string[] = [];

  function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    return Promise.resolve()
      .then(fn)
      .catch((error) => {
        failures.push(
          `${name}: ${error instanceof Error ? error.message : String(error)}`,
        );
      });
  }

  await check("vault recovery secret round-trips", () => {
    const encoded = createVaultRecoverySecret();
    const decoded = decodeVaultRecoverySecret(encoded);
    assert.ok(decoded);
    assert.equal(decoded?.length, 32);
  });

  await check("recovery secret field accepts base64url, base64, and hex", () => {
    const secret = randomBytes(32);
    const base64Url = secret.toString("base64url");
    const standardBase64 = secret.toString("base64");
    const hex = secret.toString("hex");

    assert.ok(decodeVaultRecoverySecretField(base64Url)?.equals(secret));
    assert.ok(decodeVaultRecoverySecretField(standardBase64)?.equals(secret));
    assert.ok(decodeVaultRecoverySecretField(hex)?.equals(secret));
    assert.equal(decodeVaultRecoverySecretField("not-a-key"), null);
  });

  await check("vault format decrypts encrypted PCM frames", () => {
    const secret = randomBytes(32);
    const pcm = Buffer.from([0, 1, 2, 3, 4, 5, 6, 7]);
    const vault = buildEncryptedVault(secret, pcm);
    const header = parseVaultHeader(vault);
    assert.equal(header.sampleRateHz, 16000);
    const decrypted = decryptVaultFile(vault, secret);
    assert.equal(decrypted.frameCount, 1);
    assert.ok(decrypted.pcm16Le.equals(pcm));
    const wav = wrapPcm16LeInWav(
      decrypted.pcm16Le,
      decrypted.header.sampleRateHz,
      decrypted.header.numChannels,
    );
    assert.match(wav.subarray(0, 4).toString("ascii"), /RIFF/);
  });

  await check("vault recovery store deduplicates idempotency keys", () => {
    resetVaultRecoveryStoreForTest();
    const secret = createVaultRecoverySecret();
    registerVaultRecoverySession({
      sessionId: "session_test",
      subject: "device:test",
      vaultRecoverySecretBase64: secret,
    });
    const lookup = lookupVaultRecoverySession("session_test", "device:test");
    assert.equal(lookup.ok, true);

    const reflection = parseReflectionResponse(
      JSON.stringify({
        mood: "steady",
        emotionalIntensity: 3,
        recurringThemes: ["connection"],
        exactLanguagePattern: "I need to finish this",
        concreteObservation: "You named the pressure directly.",
        repeatedSignal: "Finish this",
        tensionOrContradiction: "",
        avoidedOrVagueArea: "",
        nextSmallAction: "",
      }),
      "I need to finish this",
    );
    recordVaultRecoveryAck({
      sessionId: "session_test",
      idempotencyKey: "idem_1",
      recoveryAckId: "ack_1",
      transcript: "I need to finish this",
      reflection,
      durationSeconds: 12,
    });
    const ack = lookupVaultRecoveryAck("session_test", "idem_1");
    assert.ok(ack);
    assert.equal(ack?.recoveryAckId, "ack_1");
  });

  return { failures };
}
