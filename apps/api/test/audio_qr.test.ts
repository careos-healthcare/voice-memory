import assert from "node:assert/strict";
import test from "node:test";

import {
  AUDIO_QR_TTL_MS,
  MemoryAudioQrStore,
  createAudioQrLink,
  signAudioQrToken,
  verifyAudioQrToken,
} from "../src/routes/export/audio-qr.ts";

const secret = "test-audio-qr-secret";
const now = Date.parse("2026-09-26T06:00:00.000Z");

test("a signed audio link expires after 30 days", async () => {
  const store = new MemoryAudioQrStore();
  const created = await createAudioQrLink({
    userId: "user-1",
    ciphertext: Buffer.from([9, 8, 7]),
    nonce: Buffer.from("123456789012").toString("base64"),
    mac: Buffer.from("1234567890123456").toString("base64"),
    origin: "https://example.com",
    store,
    secret,
    now,
  });
  assert.equal("url" in created, true);
  if (!("url" in created)) return;
  const expiresAt = Date.parse(created.expiresAt);
  assert.equal(expiresAt - now, AUDIO_QR_TTL_MS);
  const token = new URL(created.url).searchParams.get("t");
  assert.ok(token);
  const verified = verifyAudioQrToken(token, secret, now);
  assert.ok(verified);
  assert.equal(verified.expiresAt, expiresAt);
  assert.equal(verified.id.length, 32);
  assert.equal(verifyAudioQrToken(token, secret, expiresAt + 1), null);
  assert.equal(verifyAudioQrToken(token, "other-secret", now), null);
});

test("a tampered token is rejected", () => {
  const token = signAudioQrToken("a".repeat(32), now + 1000, secret);
  const [encoded] = token.split(".");
  assert.equal(verifyAudioQrToken(`${encoded}.not-the-signature`, secret, now), null);
});

test("empty or oversized audio is refused", async () => {
  const store = new MemoryAudioQrStore();
  const nonce = Buffer.from("123456789012").toString("base64");
  const mac = Buffer.from("1234567890123456").toString("base64");
  const empty = await createAudioQrLink({
    userId: "user-1",
    ciphertext: Buffer.alloc(0),
    nonce,
    mac,
    origin: "https://example.com",
    store,
    secret,
    now,
  });
  assert.deepEqual(empty, { error: "invalid" });
  const huge = await createAudioQrLink({
    userId: "user-1",
    ciphertext: Buffer.alloc(12 * 1024 * 1024 + 1),
    nonce,
    mac,
    origin: "https://example.com",
    store,
    secret,
    now,
  });
  assert.deepEqual(huge, { error: "too_large" });
});
