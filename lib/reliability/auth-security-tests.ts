import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import {
  CODE_TTL_MS,
  MAX_CODE_ATTEMPTS,
  SEND_COOLDOWN_MS,
  SEND_IP_MAX_PER_WINDOW,
  createSecureVerificationCode,
  evaluateCodeAttempt,
  recordSendCodeIpHit,
  resetSendCodeIpBucketsForTest,
  sendAllowed,
} from "@/lib/auth/auth-code-policy";

const ROOT = process.cwd();

function readSource(rel: string): string {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

export async function runAuthSecurityTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  // --- code expiry ---

  await check("code TTL is 10 minutes", () => {
    assert.equal(CODE_TTL_MS, 10 * 60 * 1000);
  });

  await check("expired code is rejected and invalidated", () => {
    const now = Date.now();
    const decision = evaluateCodeAttempt({
      pending: { expiresAtMs: now - 1, attempts: 0 },
      hashMatches: true,
      nowMs: now,
    });
    assert.equal(decision.outcome, "expired");
    assert.equal(decision.invalidate, true);
  });

  // --- attempt limit ---

  await check("mismatches increment attempts and lock at the limit", () => {
    const now = Date.now();
    let attempts = 0;
    for (let i = 0; i < MAX_CODE_ATTEMPTS; i++) {
      const decision = evaluateCodeAttempt({
        pending: { expiresAtMs: now + CODE_TTL_MS, attempts },
        hashMatches: false,
        nowMs: now,
      });
      assert.equal(decision.outcome, "mismatch");
      if (decision.outcome === "mismatch") {
        attempts = decision.nextAttempts;
        assert.equal(decision.invalidate, attempts >= MAX_CODE_ATTEMPTS);
      }
    }
    assert.equal(attempts, MAX_CODE_ATTEMPTS);
  });

  await check("correct code is rejected once the attempt limit is reached", () => {
    const now = Date.now();
    const decision = evaluateCodeAttempt({
      pending: { expiresAtMs: now + CODE_TTL_MS, attempts: MAX_CODE_ATTEMPTS },
      hashMatches: true,
      nowMs: now,
    });
    assert.equal(decision.outcome, "locked");
    assert.equal(decision.invalidate, true);
  });

  await check("matching code is consumed (single use)", () => {
    const now = Date.now();
    const decision = evaluateCodeAttempt({
      pending: { expiresAtMs: now + CODE_TTL_MS, attempts: 1 },
      hashMatches: true,
      nowMs: now,
    });
    assert.equal(decision.outcome, "match");
    assert.equal(decision.invalidate, true);
  });

  // --- resend rate limit ---

  await check("resend within the cooldown is blocked with retry hint", () => {
    const now = Date.now();
    const blocked = sendAllowed(now - 1000, now);
    assert.equal(blocked.allowed, false);
    assert.ok(blocked.retryAfterMs > 0 && blocked.retryAfterMs <= SEND_COOLDOWN_MS);
  });

  await check("resend after the cooldown is allowed", () => {
    const now = Date.now();
    assert.equal(sendAllowed(now - SEND_COOLDOWN_MS, now).allowed, true);
    assert.equal(sendAllowed(null, now).allowed, true);
  });

  await check("per-IP burst limiter blocks after the window cap", () => {
    resetSendCodeIpBucketsForTest();
    const key = `test-ip-${Date.now()}`;
    const now = Date.now();
    let lastAllowed = true;
    for (let i = 0; i < SEND_IP_MAX_PER_WINDOW; i++) {
      lastAllowed = recordSendCodeIpHit(key, now);
      assert.equal(lastAllowed, true);
    }
    assert.equal(recordSendCodeIpHit(key, now), false);
    resetSendCodeIpBucketsForTest();
  });

  // --- secure code generation ---

  await check("verification codes are 6 digits from a CSPRNG", () => {
    for (let i = 0; i < 200; i++) {
      const code = createSecureVerificationCode();
      assert.match(code, /^\d{6}$/);
      const n = Number(code);
      assert.ok(n >= 100000 && n <= 999999);
    }
    const crypto = readSource("lib/server/auth-crypto.ts");
    assert.ok(!crypto.includes("Math.random"), "auth-crypto must not use Math.random");
    assert.ok(crypto.includes("createSecureVerificationCode"));
  });

  // --- stores enforce the policy and hash codes ---

  await check("local store hashes codes and applies policy", () => {
    const store = readSource("lib/server/auth-store.ts");
    assert.ok(store.includes("hashVerificationCode"));
    assert.ok(store.includes("evaluateCodeAttempt"));
    assert.ok(store.includes("sendAllowed"));
    assert.ok(store.includes("AuthRateLimitError"));
  });

  await check("postgres store hashes codes, limits attempts, deletes on match", () => {
    const store = readSource("lib/server/auth-store-postgres.ts");
    assert.ok(store.includes("hashVerificationCode"));
    assert.ok(store.includes("MAX_CODE_ATTEMPTS"));
    assert.ok(store.includes("attempts = attempts + 1"));
    assert.ok(store.includes("DELETE FROM auth_codes"));
    assert.ok(store.includes("sendAllowed"));
    assert.ok(!/INSERT INTO auth_codes[^;]*\$\{/.test(store), "no string interpolation in SQL");
  });

  await check("schema includes the attempts column migration", () => {
    const db = readSource("lib/server/db.ts");
    assert.ok(
      db.includes("ALTER TABLE auth_codes ADD COLUMN IF NOT EXISTS attempts"),
      "auth_codes.attempts migration missing from bundled schema",
    );
  });

  // --- cookie flags and session expiry ---

  await check("session cookie is HttpOnly, SameSite, Secure in production, with expiry", () => {
    const session = readSource("lib/server/session.ts");
    assert.ok(session.includes("httpOnly: true"));
    assert.ok(session.includes('sameSite: "lax"'));
    assert.ok(session.includes('secure: process.env.NODE_ENV === "production"'));
    assert.ok(session.includes("maxAge: 60 * 60 * 24 * 30"));
  });

  await check("session tokens carry expiry and signout revokes server-side", () => {
    const crypto = readSource("lib/server/auth-crypto.ts");
    assert.ok(crypto.includes("if (Date.now() > payload.exp) return null"));
    const signout = readSource("app/api/auth/signout/route.ts");
    assert.ok(signout.includes("revokeServerSession"));
    assert.ok(signout.includes("clearSessionCookie"));
  });

  // --- redacted logging and safe responses ---

  await check("send-code route rate limits and logs hashed email only", () => {
    const route = readSource("app/api/auth/send-code/route.ts");
    assert.ok(route.includes("hashEmailForLog("));
    assert.ok(route.includes("AUTH_RATE_LIMITED"));
    assert.ok(route.includes("recordSendCodeIpHit"));
    // The only raw-code log must stay behind the non-production guard.
    const prodGuardIndex = route.indexOf('process.env.NODE_ENV !== "production"');
    const rawCodeLogIndex = route.indexOf("Sign-in code for");
    assert.ok(prodGuardIndex >= 0 && rawCodeLogIndex > prodGuardIndex);
  });

  await check("verify route never echoes internal error details", () => {
    const route = readSource("app/api/auth/verify/route.ts");
    assert.ok(!route.includes("error.message"), "verify must not return error.message");
    assert.ok(route.includes("Sign-in failed."));
  });

  await check("auth secret is required in production", () => {
    const crypto = readSource("lib/server/auth-crypto.ts");
    assert.ok(crypto.includes("AUTH_SECRET is required in production"));
    const env = readSource("lib/server/production-env.ts");
    assert.ok(env.includes("isAuthSecretStrong"));
  });

  await check("production postgres TLS verifies certificates", () => {
    const db = readSource("lib/server/db.ts");
    assert.ok(db.includes("rejectUnauthorized: true"), "production must verify TLS");
    assert.ok(
      db.includes("DATABASE_SSL_REJECT_UNAUTHORIZED=false is forbidden in production"),
      "insecure TLS override must fail production validation",
    );
    assert.ok(db.includes("DATABASE_SSL_CA_BUNDLE"), "optional CA bundle must be supported");
  });

  await check("encrypted sync push rejects oversized bodies and validates envelopes", () => {
    const route = readSource("app/api/sync/push/route.ts");
    assert.ok(route.includes("MAX_SYNC_PUSH_BLOBS"));
    assert.ok(route.includes("MAX_SYNC_PUSH_BODY_BYTES"));
    assert.ok(route.includes("MAX_SYNC_BLOB_BYTES"));
    assert.ok(route.includes("INVALID_REMOTE_TIMESTAMP"));
    assert.ok(route.includes("UNSUPPORTED_ENCRYPTION_VERSION"));
    assert.ok(!route.includes("console.log"), "sync push must not log envelope content");
  });

  return { failures };
}
