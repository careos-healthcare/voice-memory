import "server-only";

import { createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";

import { createSecureVerificationCode } from "@/lib/auth/auth-code-policy";

const SESSION_TTL_MS = 1000 * 60 * 60 * 24 * 30;

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

export interface SessionTokenPayload {
  userId: string;
  email: string;
  exp: number;
}

export function hashVerificationCode(code: string): string {
  return createHash("sha256").update(`${code}:${authSecret()}`).digest("hex");
}

/** 6 digits from a CSPRNG — sign-in codes must never use a weak PRNG. */
export function createVerificationCode(): string {
  return createSecureVerificationCode();
}

export function createUserId(): string {
  return randomBytes(16).toString("hex");
}

export function userIdFromEmail(email: string): string {
  const normalized = email.trim().toLowerCase();
  return createHash("sha256")
    .update(`user:${normalized}:${authSecret()}`)
    .digest("hex")
    .slice(0, 32);
}

export function hashSessionToken(token: string): string {
  return createHash("sha256").update(`session:${token}:${authSecret()}`).digest("hex");
}

/**
 * Short, one-way hash of a userId for structured audit logs (e.g. account
 * deletion). Never reversible to the original id in practice, and never the
 * same value as `userIdFromEmail`'s output space (distinct salt prefix), so
 * it can't be replayed as a session/user lookup key.
 */
export function hashUserIdForAudit(userId: string): string {
  return createHash("sha256")
    .update(`audit:${userId}:${authSecret()}`)
    .digest("hex")
    .slice(0, 12);
}

export function signSessionToken(payload: Omit<SessionTokenPayload, "exp">): string {
  const body: SessionTokenPayload = {
    ...payload,
    exp: Date.now() + SESSION_TTL_MS,
  };
  const encoded = Buffer.from(JSON.stringify(body)).toString("base64url");
  const signature = createHmac("sha256", authSecret()).update(encoded).digest("base64url");
  return `${encoded}.${signature}`;
}

export function verifySessionToken(token: string): SessionTokenPayload | null {
  const [encoded, signature] = token.split(".");
  if (!encoded || !signature) return null;

  const expected = createHmac("sha256", authSecret()).update(encoded).digest("base64url");
  const sigBuffer = Buffer.from(signature);
  const expectedBuffer = Buffer.from(expected);
  if (sigBuffer.length !== expectedBuffer.length) return null;
  if (!timingSafeEqual(sigBuffer, expectedBuffer)) return null;

  try {
    const payload = JSON.parse(Buffer.from(encoded, "base64url").toString("utf8")) as SessionTokenPayload;
    if (!payload.userId || !payload.email || !payload.exp) return null;
    if (Date.now() > payload.exp) return null;
    return payload;
  } catch {
    return null;
  }
}

export const SESSION_COOKIE = "vm_session";
