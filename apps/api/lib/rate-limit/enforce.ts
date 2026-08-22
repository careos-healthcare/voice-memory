import type { IncomingMessage } from "node:http";

import { SESSION_COOKIE, verifySessionToken } from "@/lib/server/auth-crypto";
import {
  GLOBAL_RATE_LIMIT_MAX_REQUESTS,
  GLOBAL_RATE_LIMIT_WINDOW_MS,
  shouldApplyGlobalRateLimit,
} from "@/lib/rate-limit/constants";
import {
  closeRedisClient,
  getRedisClient,
  isRedisRateLimitConfigured,
} from "@/lib/rate-limit/redis-client";
import { checkSlidingWindowRateLimit } from "@/lib/rate-limit/sliding-window";

export interface GlobalRateLimitDecision {
  allowed: boolean;
  subject: string;
  remaining: number;
  retryAfterMs: number;
  mode: "redis" | "disabled";
}

export function resolveRateLimitSubject(req: IncomingMessage): string {
  const sessionToken = readCookie(req, SESSION_COOKIE);
  if (sessionToken) {
    const payload = verifySessionToken(sessionToken);
    if (payload?.userId) {
      return `user:${payload.userId}`;
    }
  }

  const realIp = req.headers["x-real-ip"];
  const ip =
    (typeof realIp === "string"
      ? realIp.trim()
      : Array.isArray(realIp)
        ? realIp[0]?.trim()
        : undefined) ??
    req.socket.remoteAddress ??
    "local";

  return `ip:${ip}`;
}

function readCookie(req: IncomingMessage, name: string): string | null {
  const header = req.headers.cookie;
  if (!header) return null;

  for (const part of header.split(";")) {
    const trimmed = part.trim();
    if (!trimmed.startsWith(`${name}=`)) continue;
    return decodeURIComponent(trimmed.slice(name.length + 1));
  }

  return null;
}

function buildRateLimitKey(subject: string, pathname: string): string {
  return `ratelimit:global:${subject}:${pathname}`;
}

export async function enforceGlobalRateLimitForNodeRequest(
  req: IncomingMessage,
  pathname: string,
): Promise<GlobalRateLimitDecision> {
  const subject = resolveRateLimitSubject(req);

  if (!shouldApplyGlobalRateLimit(pathname)) {
    return {
      allowed: true,
      subject,
      remaining: GLOBAL_RATE_LIMIT_MAX_REQUESTS,
      retryAfterMs: 0,
      mode: isRedisRateLimitConfigured() ? "redis" : "disabled",
    };
  }

  const redis = getRedisClient();
  if (!redis) {
    if (process.env.NODE_ENV === "production") {
      throw new Error("REDIS_URL is required in production for global rate limiting.");
    }

    return {
      allowed: true,
      subject,
      remaining: GLOBAL_RATE_LIMIT_MAX_REQUESTS,
      retryAfterMs: 0,
      mode: "disabled",
    };
  }

  const decision = await checkSlidingWindowRateLimit(
    redis,
    buildRateLimitKey(subject, pathname),
    {
      windowMs: GLOBAL_RATE_LIMIT_WINDOW_MS,
      maxRequests: GLOBAL_RATE_LIMIT_MAX_REQUESTS,
    },
  );

  return {
    allowed: decision.allowed,
    subject,
    remaining: decision.remaining,
    retryAfterMs: decision.retryAfterMs,
    mode: "redis",
  };
}

export { closeRedisClient, isRedisRateLimitConfigured };
