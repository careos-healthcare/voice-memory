import { createHmac, randomUUID, timingSafeEqual } from "node:crypto";

import { LIVE_SESSION_TTL_MS } from "@/lib/live-audio/constants";

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

export interface LiveAudioSessionPayload {
  sessionId: string;
  subject: string;
  exp: number;
  jti: string;
  ipHash?: string;
  uaHash?: string;
}

export function signLiveAudioSessionToken(
  subject: string,
  binding?: { ipHash: string; uaHash: string },
): { token: string; payload: LiveAudioSessionPayload } {
  const payload: LiveAudioSessionPayload = {
    sessionId: randomUUID(),
    subject,
    exp: Date.now() + LIVE_SESSION_TTL_MS,
    jti: randomUUID(),
    ...(binding ? { ipHash: binding.ipHash, uaHash: binding.uaHash } : {}),
  };
  const encoded = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const signature = createHmac("sha256", authSecret()).update(encoded).digest("base64url");
  return { token: `${encoded}.${signature}`, payload };
}

export function verifyLiveAudioSessionToken(
  token: string,
  binding?: { ipHash?: string; uaHash?: string },
): LiveAudioSessionPayload | null {
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
    ) as LiveAudioSessionPayload;
    if (!payload.sessionId || !payload.subject || !payload.exp || !payload.jti) {
      return null;
    }
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
