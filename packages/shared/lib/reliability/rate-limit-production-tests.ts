import assert from "node:assert/strict";

import {
  checkAndRecordApiUsage,
  peekDayUsage,
  usesDurableRateLimits,
} from "@/lib/server/api-usage-store";
import { assertProductionRateLimiterIsDurable } from "@/lib/server/api-usage-store";

export async function runRateLimitProductionTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  const userSubject = `user:rate-test-${Date.now()}`;
  const deviceSubject = `device:rate-test-${Date.now()}`;
  const ipSubject = `ip:rate-test-${Date.now()}`;

  await check("subjects are independent", async () => {
    await checkAndRecordApiUsage(userSubject, "transcribe");
    await checkAndRecordApiUsage(deviceSubject, "analyze");
    const userDay = await peekDayUsage(userSubject);
    const deviceDay = await peekDayUsage(deviceSubject);
    assert.equal(userDay.transcribe, 1);
    assert.equal(deviceDay.analyze, 1);
    assert.equal(userDay.analyze, 0);
  });

  await check("attest endpoint has daily bucket", async () => {
    const s = `ip:attest-${Date.now()}`;
    await checkAndRecordApiUsage(s, "attest");
    const day = await peekDayUsage(s);
    assert.ok(day.attest >= 1);
  });

  await check("minute burst eventually blocks", async () => {
    const s = `user:burst-${Date.now()}`;
    const limit = Number(process.env.VOICEMEMORY_MINUTE_TRANSCRIBE_LIMIT ?? "6");
    let last = { allowed: true as boolean };
    for (let i = 0; i < limit + 3; i++) {
      last = await checkAndRecordApiUsage(s, "transcribe");
    }
    assert.equal(last.allowed, false);
  });

  await check("production limiter assertion matches DATABASE_URL", () => {
    if (process.env.NODE_ENV === "production" && !usesDurableRateLimits()) {
      assert.throws(() => assertProductionRateLimiterIsDurable());
    } else if (usesDurableRateLimits()) {
      assert.doesNotThrow(() => assertProductionRateLimiterIsDurable());
    }
  });

  await check("ip subject tracked separately", async () => {
    const s = `ip:sep-${Date.now()}`;
    await checkAndRecordApiUsage(s, "atmosphere");
    const day = await peekDayUsage(s);
    assert.ok(day.atmosphere >= 1);
  });

  return { failures };
}
