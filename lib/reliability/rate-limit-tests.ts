import assert from "node:assert/strict";

import {
  checkAndRecordApiUsage,
  peekDayUsage,
  usesDurableRateLimits,
  type UsageCheckResult,
} from "@/lib/server/api-usage-store";

export async function runRateLimitTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  const subject = `test-rate-${Date.now()}`;

  await check("minute burst blocks after limit", async () => {
    const limit = Number(process.env.VOICEMEMORY_MINUTE_ATTEST_LIMIT ?? "12");
    let last: UsageCheckResult = { allowed: true };
    for (let i = 0; i < limit + 2; i++) {
      last = await checkAndRecordApiUsage(subject, "attest");
    }
    assert.equal(last.allowed, false);
    assert.equal(last.reason, "minute_burst");
  });

  await check("daily counter increments in memory/pg", async () => {
    const daySubject = `test-day-${Date.now()}`;
    await checkAndRecordApiUsage(daySubject, "transcribe");
    const row = await peekDayUsage(daySubject);
    assert.ok(row.transcribe >= 1);
  });

  await check("durable flag matches DATABASE_URL", () => {
    const expected = Boolean(process.env.DATABASE_URL?.trim());
    assert.equal(usesDurableRateLimits(), expected);
  });

  return { failures };
}
