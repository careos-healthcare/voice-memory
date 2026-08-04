import { NextResponse } from "next/server";

import { authorizeInternalPushApi } from "@/lib/push/internal-api-auth";
import { recordRollupBreaches } from "@/lib/server/unit-economics-breach-store";
import { authorizeUnitEconomicsCron } from "@/lib/server/unit-economics-cron";
import { reconcileDailySubjectRollup } from "@/lib/server/unit-economics-engine";
import { listUsageSubjectDays } from "@/lib/server/unit-economics-ledger-store";
import {
  boundedEconomicsDateRange,
  yesterdayUtc,
} from "@/lib/server/unit-economics-route";
import { reconcileDailyStorageSnapshots } from "@/lib/server/unit-economics-storage-reconcile";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

async function reconcileRange(from: string, to: string) {
  let storageSnapshotsInserted = 0;
  for (
    let cursor = new Date(`${from}T00:00:00.000Z`);
    cursor <= new Date(`${to}T00:00:00.000Z`);
    cursor = new Date(cursor.getTime() + 86_400_000)
  ) {
    storageSnapshotsInserted += await reconcileDailyStorageSnapshots(
      cursor.toISOString().slice(0, 10),
    );
  }
  const pairs = await listUsageSubjectDays(from, to);
  let breachesInserted = 0;
  for (const pair of pairs) {
    const rollup = await reconcileDailySubjectRollup(pair.subjectKey, pair.day);
    breachesInserted += await recordRollupBreaches(rollup);
  }
  return { pairs, breachesInserted, storageSnapshotsInserted };
}

export async function GET(request: Request) {
  if (!authorizeUnitEconomicsCron(request.headers.get("authorization"))) {
    return NextResponse.json(
      { error: "Unauthorized.", code: "CRON_UNAUTHORIZED" },
      { status: 401 },
    );
  }
  const day = yesterdayUtc();
  try {
    const result = await reconcileRange(day, day);
    return NextResponse.json({
      ok: true,
      from: day,
      to: day,
      reconciled: result.pairs.length,
      storageSnapshotsInserted: result.storageSnapshotsInserted,
      breachesInserted: result.breachesInserted,
    });
  } catch {
    return NextResponse.json(
      { error: "Reconciliation failed.", code: "RECONCILIATION_FAILED" },
      { status: 500 },
    );
  }
}

export async function POST(request: Request) {
  const auth = await authorizeInternalPushApi(request);
  if (!auth.authorized) return auth.response;

  let body: { from?: string; to?: string } = {};
  try {
    const text = await request.text();
    if (text.trim()) body = JSON.parse(text) as typeof body;
  } catch {
    return NextResponse.json({ error: "Invalid request.", code: "INVALID_JSON" }, { status: 400 });
  }
  const yesterday = yesterdayUtc();
  const range = boundedEconomicsDateRange(body.from, body.to, {
    from: yesterday,
    to: yesterday,
  });
  if (!range.ok) {
    return NextResponse.json({ error: "Invalid date range.", code: range.code }, { status: 400 });
  }

  const result = await reconcileRange(range.from, range.to);
  return NextResponse.json({
    ok: true,
    from: range.from,
    to: range.to,
    reconciled: result.pairs.length,
    storageSnapshotsInserted: result.storageSnapshotsInserted,
    breachesInserted: result.breachesInserted,
  });
}
