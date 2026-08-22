import assert from "node:assert/strict";

import { signSessionToken } from "../../../../packages/shared/lib/server/auth-crypto";
import { resolveRateLimitSubject } from "./enforce";

export async function runGlobalRateLimitSubjectTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  try {
    process.env.AUTH_SECRET = "test-global-rate-limit-secret-32chars-min";
    const token = signSessionToken({
      userId: "user-123",
      email: "test@example.com",
    });
    const req = {
      headers: { cookie: `vm_session=${encodeURIComponent(token)}` },
      socket: { remoteAddress: "127.0.0.1" },
    } as import("node:http").IncomingMessage;
    assert.equal(resolveRateLimitSubject(req), "user:user-123");

    const ipReq = {
      headers: {},
      socket: { remoteAddress: "203.0.113.10" },
    } as import("node:http").IncomingMessage;
    assert.equal(resolveRateLimitSubject(ipReq), "ip:203.0.113.10");

    const realIpReq = {
      headers: {
        "x-real-ip": "198.51.100.5",
        "x-forwarded-for": "1.2.3.4",
      },
      socket: { remoteAddress: "203.0.113.10" },
    } as unknown as import("node:http").IncomingMessage;
    assert.equal(resolveRateLimitSubject(realIpReq), "ip:198.51.100.5");
  } catch (error) {
    failures.push(
      `subject resolution: ${error instanceof Error ? error.message : String(error)}`,
    );
  }

  return { failures };
}
