import { randomInt } from "node:crypto";

/**
 * Pure email-code policy shared by the local and Postgres auth stores —
 * no "server-only" import so the reliability test runner can exercise it
 * directly. Holds the security constants and the state transitions for
 * issuing and verifying codes. Never logs or returns anything beyond the
 * decision itself.
 */

/** A sign-in code is valid for 10 minutes. */
export const CODE_TTL_MS = 10 * 60 * 1000;

/** A code dies after this many wrong guesses, even inside the TTL. */
export const MAX_CODE_ATTEMPTS = 5;

/** Minimum gap between two codes for the same email. */
export const SEND_COOLDOWN_MS = 60 * 1000;

/** Best-effort per-IP cap on send-code requests per window (per instance). */
export const SEND_IP_WINDOW_MS = 10 * 60 * 1000;
export const SEND_IP_MAX_PER_WINDOW = 10;

/** Thrown when a resend arrives before the cooldown elapsed. */
export class AuthRateLimitError extends Error {
  constructor(public readonly retryAfterMs: number) {
    super("Too many requests. Try again shortly.");
    this.name = "AuthRateLimitError";
  }
}

/** 6 digits from a CSPRNG — never Math.random. */
export function createSecureVerificationCode(): string {
  return String(randomInt(100000, 1000000));
}

export function sendAllowed(
  lastIssuedAtMs: number | null,
  nowMs: number,
): { allowed: boolean; retryAfterMs: number } {
  if (lastIssuedAtMs === null) return { allowed: true, retryAfterMs: 0 };
  const elapsed = nowMs - lastIssuedAtMs;
  if (elapsed >= SEND_COOLDOWN_MS) return { allowed: true, retryAfterMs: 0 };
  return { allowed: false, retryAfterMs: SEND_COOLDOWN_MS - elapsed };
}

export interface PendingCodeState {
  expiresAtMs: number;
  attempts: number;
}

export type CodeAttemptOutcome =
  | { outcome: "match"; invalidate: true }
  | { outcome: "expired"; invalidate: true }
  | { outcome: "locked"; invalidate: true }
  | { outcome: "mismatch"; invalidate: boolean; nextAttempts: number };

/**
 * One verification attempt against the pending code. A match consumes the
 * code; expiry or exceeding [MAX_CODE_ATTEMPTS] invalidates it; a mismatch
 * increments the counter (and invalidates once the limit is reached).
 */
export function evaluateCodeAttempt(args: {
  pending: PendingCodeState | null;
  hashMatches: boolean;
  nowMs: number;
}): CodeAttemptOutcome | { outcome: "missing"; invalidate: false } {
  const { pending, hashMatches, nowMs } = args;
  if (!pending) return { outcome: "missing", invalidate: false };
  if (pending.expiresAtMs <= nowMs) return { outcome: "expired", invalidate: true };
  if (pending.attempts >= MAX_CODE_ATTEMPTS) {
    return { outcome: "locked", invalidate: true };
  }
  if (hashMatches) return { outcome: "match", invalidate: true };
  const nextAttempts = pending.attempts + 1;
  return {
    outcome: "mismatch",
    nextAttempts,
    invalidate: nextAttempts >= MAX_CODE_ATTEMPTS,
  };
}

interface IpBucket {
  count: number;
  resetAt: number;
}

const globalBuckets = globalThis as typeof globalThis & {
  __vmAuthSendIpBuckets?: Map<string, IpBucket>;
};

function ipBuckets(): Map<string, IpBucket> {
  if (!globalBuckets.__vmAuthSendIpBuckets) {
    globalBuckets.__vmAuthSendIpBuckets = new Map();
  }
  return globalBuckets.__vmAuthSendIpBuckets;
}

/**
 * Best-effort in-memory per-IP limiter for send-code (per server
 * instance). The durable per-email cooldown is the primary control; this
 * only blunts single-instance bursts. Keys should already be hashes —
 * never raw IPs.
 */
export function recordSendCodeIpHit(ipKey: string, nowMs: number): boolean {
  const buckets = ipBuckets();
  if (buckets.size > 10_000) buckets.clear();
  const bucket = buckets.get(ipKey);
  if (!bucket || nowMs > bucket.resetAt) {
    buckets.set(ipKey, { count: 1, resetAt: nowMs + SEND_IP_WINDOW_MS });
    return true;
  }
  bucket.count += 1;
  return bucket.count <= SEND_IP_MAX_PER_WINDOW;
}

export function resetSendCodeIpBucketsForTest(): void {
  ipBuckets().clear();
}
