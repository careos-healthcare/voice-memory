import "server-only";

import { createHmac, timingSafeEqual } from "node:crypto";

const TOKEN_TTL_MS = 15 * 60 * 1000;
const DEVICE_ID = /^[A-Za-z0-9_.:-]{1,128}$/;
const VAULT_HASH = /^[a-f0-9]{64}$/;

export interface CloudRelayAccess {
  vaultHash: string;
  deviceId: string;
  expiresAt: number;
}

function relaySecret(): string {
  const secret = process.env.SYNC_RELAY_TOKEN_SECRET ?? process.env.AUTH_SECRET;
  if (!secret) {
    if (process.env.NODE_ENV === "production") {
      throw new Error(
        "SYNC_RELAY_TOKEN_SECRET or AUTH_SECRET is required in production",
      );
    }
    return "dev-only-cloud-relay-secret-change-me";
  }
  return secret;
}

export function saltedVaultHash(userId: string): string {
  if (!userId) throw new Error("User id is required.");
  return createHmac("sha256", relaySecret())
    .update(`cloud-relay-vault:v1:${userId}`)
    .digest("hex");
}

export function mintCloudRelayToken(
  userId: string,
  deviceId: string,
  now = Date.now(),
): { token: string; access: CloudRelayAccess } {
  if (!DEVICE_ID.test(deviceId)) throw new Error("Invalid relay device id.");
  const access: CloudRelayAccess = {
    vaultHash: saltedVaultHash(userId),
    deviceId,
    expiresAt: now + TOKEN_TTL_MS,
  };
  const encoded = Buffer.from(JSON.stringify(access)).toString("base64url");
  const signature = createHmac("sha256", relaySecret())
    .update(`cloud-relay-token:v1:${encoded}`)
    .digest("base64url");
  return { token: `${encoded}.${signature}`, access };
}

export function verifyCloudRelayToken(
  token: string,
  now = Date.now(),
): CloudRelayAccess | null {
  const [encoded, signature, extra] = token.split(".");
  if (!encoded || !signature || extra) return null;
  const expected = createHmac("sha256", relaySecret())
    .update(`cloud-relay-token:v1:${encoded}`)
    .digest("base64url");
  const actualBytes = Buffer.from(signature);
  const expectedBytes = Buffer.from(expected);
  if (
    actualBytes.length !== expectedBytes.length ||
    !timingSafeEqual(actualBytes, expectedBytes)
  ) {
    return null;
  }
  try {
    const parsed = JSON.parse(
      Buffer.from(encoded, "base64url").toString("utf8"),
    ) as Partial<CloudRelayAccess>;
    if (
      typeof parsed.vaultHash !== "string" ||
      !VAULT_HASH.test(parsed.vaultHash) ||
      typeof parsed.deviceId !== "string" ||
      !DEVICE_ID.test(parsed.deviceId) ||
      typeof parsed.expiresAt !== "number" ||
      !Number.isSafeInteger(parsed.expiresAt) ||
      now >= parsed.expiresAt
    ) {
      return null;
    }
    return {
      vaultHash: parsed.vaultHash,
      deviceId: parsed.deviceId,
      expiresAt: parsed.expiresAt,
    };
  } catch {
    return null;
  }
}

export function bearerToken(request: Request): string | null {
  const authorization = request.headers.get("authorization")?.trim() ?? "";
  if (!authorization.startsWith("Bearer ")) return null;
  const token = authorization.slice("Bearer ".length).trim();
  return token || null;
}
