import assert from "node:assert/strict";

import {
  estimateAnalyzeCost,
  estimateTranscribeCost,
  maxEstimateForOpenAiKind,
  MICRO_USD_PER_DOLLAR,
} from "@/lib/server/openai-cost-estimator";
import {
  getOpenAiBudgetLimits,
  reserveOpenAiBudget,
} from "@/lib/server/openai-budget-core";
import { peekOpenAiSpend, reserveOpenAiSpend } from "@/lib/server/openai-spend-store";

export async function runOpenAiBudgetTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  await check("transcribe estimate is positive", () => {
    const micro = estimateTranscribeCost({ durationSeconds: 60 });
    assert.ok(micro > 0);
    assert.ok(micro < MICRO_USD_PER_DOLLAR);
  });

  await check("analyze scales with transcript length", () => {
    const small = estimateAnalyzeCost(200);
    const large = estimateAnalyzeCost(20_000);
    assert.ok(large >= small);
  });

  await check("max estimate covers route ceiling", () => {
    assert.ok(maxEstimateForOpenAiKind("transcribe") >= estimateTranscribeCost({ durationSeconds: 30 }));
  });

  const subject = `test-openai-spend-${Date.now()}`;

  await check("spend reserve blocks over limit", async () => {
    const limit = 5_000;
    const first = await reserveOpenAiSpend(subject, 3_000, limit);
    assert.equal(first.ok, true);
    const second = await reserveOpenAiSpend(subject, 3_000, limit);
    assert.equal(second.ok, false);
    const spent = await peekOpenAiSpend(subject);
    assert.equal(spent, 3_000);
  });

  await check("budget guard denies when global cap tiny", async () => {
    const prev = process.env.VOICEMEMORY_OPENAI_GLOBAL_DAILY_BUDGET_USD;
    process.env.VOICEMEMORY_OPENAI_GLOBAL_DAILY_BUDGET_USD = "0.000001";
    try {
      const result = await reserveOpenAiBudget(
        {
          subject: "device:test-budget",
          via: "capture",
          deviceId: "test-budget",
        },
        "test-ip-hash",
        "transcribe",
      );
      assert.equal(result.allowed, false);
      assert.ok(result.scope);
    } finally {
      if (prev === undefined) delete process.env.VOICEMEMORY_OPENAI_GLOBAL_DAILY_BUDGET_USD;
      else process.env.VOICEMEMORY_OPENAI_GLOBAL_DAILY_BUDGET_USD = prev;
    }
  });

  await check("budget limits load from env shape", () => {
    const limits = getOpenAiBudgetLimits();
    assert.ok(limits.globalMicro > 0);
    assert.ok(limits.routeMicro.transcribe > 0);
  });

  return { failures };
}
