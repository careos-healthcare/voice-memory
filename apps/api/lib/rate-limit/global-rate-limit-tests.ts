import assert from "node:assert/strict";

import {
  GLOBAL_RATE_LIMIT_MAX_REQUESTS,
  GLOBAL_RATE_LIMIT_WINDOW_MS,
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

  await check("global rate limit budget is pinned", () => {
    // The sliding-window check below loops MAX + 1 times, so it is self-consistent
    // at any budget: raising the cap to 1200 keeps it green. These assertions are
    // what make the number itself a decision rather than a default.
    assert.equal(
      GLOBAL_RATE_LIMIT_MAX_REQUESTS,
      120,
      "global API budget is 120 requests per window — raising it needs an explicit decision",
    );
    assert.equal(
      GLOBAL_RATE_LIMIT_WINDOW_MS,
      60_000,
      "the request cap means nothing without the window it is counted over",
    );
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
