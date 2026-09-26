import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { MAX_AUDIO_BYTES } from "../../../../../packages/shared/lib/server/api-limits.ts";

export const AUDIO_QR_TTL_MS = 30 * 24 * 60 * 60 * 1000;

export type AudioQrRecord = {
  id: string;
  userId: string;
  ciphertext: Buffer;
  nonce: string;
  mac: string;
  expiresAt: number;
};

export interface AudioQrStore {
  put(record: AudioQrRecord): Promise<void>;
  get(id: string): Promise<AudioQrRecord | null>;
}

export class MemoryAudioQrStore implements AudioQrStore {
  private readonly records = new Map<string, AudioQrRecord>();

  async put(record: AudioQrRecord): Promise<void> {
    this.records.set(record.id, record);
  }

  async get(id: string): Promise<AudioQrRecord | null> {
    const record = this.records.get(id);
    if (!record) return null;
    if (Date.now() > record.expiresAt) {
      this.records.delete(id);
      return null;
    }
    return record;
  }
}

export class FileAudioQrStore implements AudioQrStore {
  private readonly directory: string;

  constructor(directory: string) {
    this.directory = directory;
  }

  async put(record: AudioQrRecord): Promise<void> {
    if (!isAudioQrId(record.id)) return;
    await mkdir(this.directory, { recursive: true });
    await writeFile(join(this.directory, `${record.id}.bin`), record.ciphertext);
    await writeFile(
      join(this.directory, `${record.id}.json`),
      JSON.stringify({
        userId: record.userId,
        nonce: record.nonce,
        mac: record.mac,
        expiresAt: record.expiresAt,
      }),
    );
  }

  async get(id: string): Promise<AudioQrRecord | null> {
    if (!isAudioQrId(id)) return null;
    const metaPath = join(this.directory, `${id}.json`);
    const binPath = join(this.directory, `${id}.bin`);
    try {
      const meta = JSON.parse(await readFile(metaPath, "utf8")) as {
        userId?: string;
        nonce?: string;
        mac?: string;
        expiresAt?: number;
      };
      if (
        typeof meta.userId !== "string" ||
        typeof meta.nonce !== "string" ||
        typeof meta.mac !== "string" ||
        typeof meta.expiresAt !== "number"
      ) {
        return null;
      }
      if (Date.now() > meta.expiresAt) {
        await rm(metaPath, { force: true });
        await rm(binPath, { force: true });
        return null;
      }
      return {
        id,
        userId: meta.userId,
        ciphertext: await readFile(binPath),
        nonce: meta.nonce,
        mac: meta.mac,
        expiresAt: meta.expiresAt,
      };
    } catch {
      return null;
    }
  }
}

export function defaultAudioQrStore(): AudioQrStore {
  return new FileAudioQrStore(join(tmpdir(), "thoughtprint-audio-qr"));
}

export function audioQrSecret(): string {
  const dedicated = process.env.AUDIO_QR_SECRET;
  if (dedicated) return dedicated;
  const secret = process.env.AUTH_SECRET;
  if (secret) return secret;
  if (process.env.NODE_ENV === "production") {
    throw new Error("AUTH_SECRET is required in production");
  }
  return "dev-only-auth-secret-change-me";
}

export function signAudioQrToken(
  id: string,
  expiresAt: number,
  secret: string,
): string {
  const encoded = Buffer.from(JSON.stringify({ id, exp: expiresAt })).toString(
    "base64url",
  );
  const signature = createHmac("sha256", secret)
    .update(`audio-qr:${encoded}`)
    .digest("base64url");
  return `${encoded}.${signature}`;
}

export function verifyAudioQrToken(
  token: string,
  secret: string,
  now = Date.now(),
): { id: string; expiresAt: number } | null {
  const [encoded, signature] = token.split(".");
  if (!encoded || !signature || token.split(".").length !== 2) return null;
  const expected = createHmac("sha256", secret)
    .update(`audio-qr:${encoded}`)
    .digest("base64url");
  const actual = Buffer.from(signature);
  const wanted = Buffer.from(expected);
  if (actual.length !== wanted.length) return null;
  if (!timingSafeEqual(actual, wanted)) return null;
  try {
    const payload = JSON.parse(
      Buffer.from(encoded, "base64url").toString("utf8"),
    ) as { id?: string; exp?: number };
    if (!payload.id || !isAudioQrId(payload.id) || typeof payload.exp !== "number") {
      return null;
    }
    if (now > payload.exp) return null;
    return { id: payload.id, expiresAt: payload.exp };
  } catch {
    return null;
  }
}

export function audioQrPlayUrl(origin: string, token: string): string {
  const url = new URL("/api/export/audio-qr", origin);
  url.searchParams.set("t", token);
  return url.toString();
}

export async function createAudioQrLink(input: {
  userId: string;
  ciphertext: Buffer;
  nonce: string;
  mac: string;
  origin: string;
  store: AudioQrStore;
  secret?: string;
  now?: number;
}): Promise<{ url: string; expiresAt: string } | { error: "invalid" | "too_large" }> {
  const nonce = decodeFixedBase64(input.nonce, 12);
  const mac = decodeFixedBase64(input.mac, 16);
  if (!nonce || !mac || input.ciphertext.length === 0) return { error: "invalid" };
  if (input.ciphertext.length > MAX_AUDIO_BYTES) return { error: "too_large" };
  const now = input.now ?? Date.now();
  const expiresAt = now + AUDIO_QR_TTL_MS;
  const id = randomBytes(16).toString("hex");
  await input.store.put({
    id,
    userId: input.userId,
    ciphertext: input.ciphertext,
    nonce: input.nonce,
    mac: input.mac,
    expiresAt,
  });
  const secret = input.secret ?? audioQrSecret();
  const token = signAudioQrToken(id, expiresAt, secret);
  return {
    url: audioQrPlayUrl(input.origin, token),
    expiresAt: new Date(expiresAt).toISOString(),
  };
}

export function audioQrPlayerHtml(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Recording</title>
</head>
<body>
  <p id="status">Opening the recording…</p>
  <audio id="player" controls></audio>
  <script>
    const status = document.getElementById("status");
    const player = document.getElementById("player");
    const key = new URLSearchParams(location.hash.replace(/^#/, "")).get("k");
    if (!key) {
      status.textContent = "This recording link has expired.";
    } else {
      const raw = new URL(location.href);
      raw.hash = "";
      raw.searchParams.set("raw", "1");
      fetch(raw.toString())
        .then(async (response) => {
          if (!response.ok) throw new Error("expired");
          const nonce = b64(response.headers.get("X-Audio-Nonce") || "");
          const mac = b64(response.headers.get("X-Audio-Mac") || "");
          const cipher = new Uint8Array(await response.arrayBuffer());
          const combined = new Uint8Array(cipher.length + mac.length);
          combined.set(cipher);
          combined.set(mac, cipher.length);
          const cryptoKey = await crypto.subtle.importKey(
            "raw",
            b64url(key),
            { name: "AES-GCM" },
            false,
            ["decrypt"],
          );
          const plain = await crypto.subtle.decrypt(
            { name: "AES-GCM", iv: nonce },
            cryptoKey,
            combined,
          );
          player.src = URL.createObjectURL(new Blob([plain], { type: "audio/mp4" }));
          status.textContent = "Recording";
        })
        .catch(() => {
          status.textContent = "This recording link has expired.";
        });
    }
    function b64(value) {
      const bin = atob(value);
      return Uint8Array.from(bin, (char) => char.charCodeAt(0));
    }
    function b64url(value) {
      const pad = value + "=".repeat((4 - (value.length % 4)) % 4);
      return b64(pad.replace(/-/g, "+").replace(/_/g, "/"));
    }
  </script>
</body>
</html>`;
}

function isAudioQrId(id: string): boolean {
  return /^[a-f0-9]{32}$/.test(id);
}

function decodeFixedBase64(value: string, length: number): Buffer | null {
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(value)) return null;
  const decoded = Buffer.from(value, "base64");
  if (decoded.length !== length) return null;
  return decoded;
}
