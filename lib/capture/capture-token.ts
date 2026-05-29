import { createHmac, randomUUID, timingSafeEqual } from "node:crypto";

/** Short-lived device capture token — bound to IP + user-agent when issued via attest. */
export const CAPTURE_TTL_MS = 1000 * 60 * 60;

const MAX_USES_DEFAULT = 500;

function authSecret(): string {
  const secret = process.env.AUTH_SECRET;
  if (!secret) {
    if (process.env.NODE_ENV === "production") {
      throw new Error("AUTH_SECRET is required in production");
    }
    return "dev-only-auth-secret-change-me";
  }
  return secret;
}

export interface CaptureTokenPayload {
  deviceId: string;
  exp: number;
  jti: string;
  ipHash?: string;
  uaHash?: string;
}

export const CAPTURE_COOKIE = "vm_capture";

export function isValidDeviceId(deviceId: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    deviceId.trim(),
  );
}

export function signCaptureToken(
  deviceId: string,
  binding?: { ipHash: string; uaHash: string },
): string {
  const body: CaptureTokenPayload = {
    deviceId: deviceId.trim(),
    exp: Date.now() + CAPTURE_TTL_MS,
    jti: randomUUID(),
    ...(binding ? { ipHash: binding.ipHash, uaHash: binding.uaHash } : {}),
  };
  const encoded = Buffer.from(JSON.stringify(body)).toString("base64url");
  const signature = createHmac("sha256", authSecret()).update(encoded).digest("base64url");
  return `${encoded}.${signature}`;
}

export function verifyCaptureToken(
  token: string,
  binding?: { ipHash?: string; uaHash?: string },
): CaptureTokenPayload | null {
  const [encoded, signature] = token.split(".");
  if (!encoded || !signature) return null;

  const expected = createHmac("sha256", authSecret()).update(encoded).digest("base64url");
  const sigBuffer = Buffer.from(signature);
  const expectedBuffer = Buffer.from(expected);
  if (sigBuffer.length !== expectedBuffer.length) return null;
  if (!timingSafeEqual(sigBuffer, expectedBuffer)) return null;

  try {
    const payload = JSON.parse(
      Buffer.from(encoded, "base64url").toString("utf8"),
    ) as CaptureTokenPayload;
    if (!payload.deviceId || !payload.exp || !payload.jti) return null;
    if (!isValidDeviceId(payload.deviceId)) return null;
    if (Date.now() > payload.exp) return null;
    if (payload.ipHash && binding?.ipHash && payload.ipHash !== binding.ipHash) {
      return null;
    }
    if (payload.uaHash && binding?.uaHash && payload.uaHash !== binding.uaHash) {
      return null;
    }
    return payload;
  } catch {
    return null;
  }
}

export function captureTokenMaxUses(): number {
  return Number(process.env.VOICEMEMORY_CAPTURE_MAX_USES ?? String(MAX_USES_DEFAULT));
}

export function buildCaptureCookie(token: string): {
  name: string;
  value: string;
  httpOnly: true;
  sameSite: "lax";
  secure: boolean;
  path: "/";
  maxAge: number;
} {
  return {
    name: CAPTURE_COOKIE,
    value: token,
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: Math.floor(CAPTURE_TTL_MS / 1000),
  };
}
