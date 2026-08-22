import type Redis from "ioredis";

import {
  GLOBAL_RATE_LIMIT_MAX_REQUESTS,
  GLOBAL_RATE_LIMIT_WINDOW_MS,
} from "./constants";

export interface SlidingWindowDecision {
  allowed: boolean;
  count: number;
  remaining: number;
  retryAfterMs: number;
}

const SLIDING_WINDOW_SCRIPT = `
redis.call('ZREMRANGEBYSCORE', KEYS[1], 0, tonumber(ARGV[1]) - tonumber(ARGV[2]))
local count = redis.call('ZCARD', KEYS[1])
if count >= tonumber(ARGV[3]) then
  return {0, count}
end
redis.call('ZADD', KEYS[1], ARGV[1], ARGV[4])
redis.call('PEXPIRE', KEYS[1], ARGV[2])
return {1, count + 1}
`;

let scriptSha: string | null = null;

async function loadScript(redis: Redis): Promise<string> {
  if (scriptSha) return scriptSha;
  const loaded = await redis.script("LOAD", SLIDING_WINDOW_SCRIPT);
  if (typeof loaded !== "string") {
    throw new Error("Failed to load Redis rate limit script");
  }
  scriptSha = loaded;
  return scriptSha;
}

export async function checkSlidingWindowRateLimit(
  redis: Redis,
  key: string,
  options?: {
    windowMs?: number;
    maxRequests?: number;
    nowMs?: number;
  },
): Promise<SlidingWindowDecision> {
  const windowMs = options?.windowMs ?? GLOBAL_RATE_LIMIT_WINDOW_MS;
  const maxRequests = options?.maxRequests ?? GLOBAL_RATE_LIMIT_MAX_REQUESTS;
  const nowMs = options?.nowMs ?? Date.now();
  const member = `${nowMs}-${Math.random().toString(36).slice(2, 10)}`;

  const sha = await loadScript(redis);
  const result = (await redis.evalsha(
    sha,
    1,
    key,
    String(nowMs),
    String(windowMs),
    String(maxRequests),
    member,
  )) as [number, number];

  const allowed = result[0] === 1;
  const count = result[1] ?? maxRequests;
  const remaining = Math.max(0, maxRequests - count);

  return {
    allowed,
    count,
    remaining,
    retryAfterMs: allowed ? 0 : windowMs,
  };
}

export function resetSlidingWindowScriptForTest(): void {
  scriptSha = null;
}
