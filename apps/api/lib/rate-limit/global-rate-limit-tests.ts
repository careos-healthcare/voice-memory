import assert from "node:assert/strict";

import {
  GLOBAL_RATE_LIMIT_MAX_REQUESTS,
  shouldApplyGlobalRateLimit,
} from "./constants";
import {
  checkSlidingWindowRateLimit,
  resetSlidingWindowScriptForTest,
} from "./sliding-window";

type MemoryEntry = { score: number; member: string };

class MemoryRedis {
  private store = new Map<string, MemoryEntry[]>();

  async script(_command: "LOAD", _source: string): Promise<string> {
    return "memory-script";
  }

  async evalsha(
    _sha: string,
    _numKeys: number,
    key: string,
    nowMs: string,
    windowMs: string,
    maxRequests: string,
    member: string,
  ): Promise<[number, number]> {
    const now = Number(nowMs);
    const window = Number(windowMs);
    const limit = Number(maxRequests);
    const entries = (this.store.get(key) ?? []).filter(
      (entry) => entry.score > now - window,
    );
    if (entries.length >= limit) {
      this.store.set(key, entries);
      return [0, entries.length];
    }
    entries.push({ score: now, member });
    this.store.set(key, entries);
    return [1, entries.length];
  }
}

export async function runGlobalRateLimitTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  await check("health routes are exempt", () => {
    assert.equal(shouldApplyGlobalRateLimit("/api/health"), false);
    assert.equal(shouldApplyGlobalRateLimit("/api/healthz"), false);
    assert.equal(shouldApplyGlobalRateLimit("/api/transcribe"), true);
  });

  await check("sliding window blocks after 120 requests", async () => {
    resetSlidingWindowScriptForTest();
    const redis = new MemoryRedis();
    const key = "ratelimit:test";
    let last = { allowed: true, remaining: GLOBAL_RATE_LIMIT_MAX_REQUESTS };

    for (let i = 0; i < GLOBAL_RATE_LIMIT_MAX_REQUESTS + 1; i++) {
      last = await checkSlidingWindowRateLimit(redis as never, key, {
        nowMs: 1_000_000 + i,
      });
    }

    assert.equal(last.allowed, false);
    assert.equal(last.remaining, 0);
  });

  return { failures };
}
