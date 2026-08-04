import { NextResponse } from "next/server";

import { authorizeInternalPushApi } from "@/lib/push/internal-api-auth";
import { summarizeThresholdBreaches } from "@/lib/server/unit-economics-breach-store";
import { aggregateDailyRollups } from "@/lib/server/unit-economics-rollup-store";
import {
  boundedEconomicsDateRange,
  ECONOMICS_SUBJECT_KEY,
  yesterdayUtc,
} from "@/lib/server/unit-economics-route";
import { summarizeCommittedUsageByPlan } from "@/lib/server/usage-reservation-store";
import { summarizeTrustedRevenueByPlan } from "@/lib/server/unit-economics-ledger-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const auth = await authorizeInternalPushApi(request);
  if (!auth.authorized) return auth.response;
  const url = new URL(request.url);
  const yesterday = yesterdayUtc();
  const range = boundedEconomicsDateRange(
    url.searchParams.get("from") ?? undefined,
    url.searchParams.get("to") ?? undefined,
    { from: yesterday, to: yesterday },
  );
  if (!range.ok) {
    return NextResponse.json({ error: "Invalid date range.", code: range.code }, { status: 400 });
  }
  const subjectKey = url.searchParams.get("subjectKey")?.trim() || undefined;
  if (subjectKey && !ECONOMICS_SUBJECT_KEY.test(subjectKey)) {
    return NextResponse.json(
      { error: "Invalid pseudonymous subject key.", code: "INVALID_SUBJECT_KEY" },
      { status: 400 },
    );
  }

  const fromInstant = new Date(`${range.from}T00:00:00.000Z`);
  const toInstant = new Date(`${range.to}T00:00:00.000Z`);
  toInstant.setUTCDate(toInstant.getUTCDate() + 1);
  const [aggregate, breaches, usageByPlan, trustedRevenueByPlan] = await Promise.all([
    aggregateDailyRollups(range.from, range.to, subjectKey),
    summarizeThresholdBreaches(range.from, range.to, subjectKey),
    summarizeCommittedUsageByPlan(fromInstant, toInstant),
    summarizeTrustedRevenueByPlan(fromInstant, toInstant),
  ]);
  const netRevenue = aggregate.revenueMicroUsd - aggregate.creditsMicroUsd;
  const marginBps =
    netRevenue > 0n
      ? ((aggregate.contributionMarginMicroUsd * 10_000n) / netRevenue).toString()
      : null;
  return NextResponse.json({
    from: range.from,
    to: range.to,
    subjectCount: aggregate.subjectCount,
    dayCount: aggregate.dayCount,
    marginBps,
    amountsMicroUsd: {
      revenue: aggregate.revenueMicroUsd.toString(),
      credits: aggregate.creditsMicroUsd.toString(),
      adjustments: aggregate.adjustmentsMicroUsd.toString(),
      contributionMargin: aggregate.contributionMarginMicroUsd.toString(),
      totalCogs: aggregate.totalCogsMicroUsd.toString(),
      cogs: {
        ai: aggregate.aiCogsMicroUsd.toString(),
        transcription: aggregate.transcriptionCogsMicroUsd.toString(),
        storage: aggregate.storageCogsMicroUsd.toString(),
        bandwidth: aggregate.bandwidthCogsMicroUsd.toString(),
        live: aggregate.liveCogsMicroUsd.toString(),
        image: aggregate.imageCogsMicroUsd.toString(),
      },
    },
    usageByPlan,
    revenueByPlan: {
      attributed: trustedRevenueByPlan.attributed.map((row) => ({
        plan: row.plan,
        revenueMicroUsd: row.revenueMicroUsd.toString(),
      })),
      unattributedRevenueMicroUsd:
        trustedRevenueByPlan.unattributedRevenueMicroUsd.toString(),
      source: "verified_provider_events_only",
    },
    breaches,
  });
}
