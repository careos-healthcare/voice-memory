import { NextResponse } from "next/server";

import { authorizeInternalPushApi } from "@/lib/push/internal-api-auth";
import { isUnitEconomicsEnabled } from "@/lib/server/unit-economics-config";
import { meterMoneyBestEffort } from "@/lib/server/unit-economics-meter";
import { parseFinanceRevenueInput } from "@/lib/server/unit-economics-revenue-input";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const auth = await authorizeInternalPushApi(request);
  if (!auth.authorized) return auth.response;
  if (!isUnitEconomicsEnabled()) {
    return NextResponse.json(
      { error: "Revenue accounting is disabled.", code: "ACCOUNTING_DISABLED" },
      { status: 503 },
    );
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { error: "Invalid request.", code: "INVALID_JSON" },
      { status: 400 },
    );
  }
  const parsed = parseFinanceRevenueInput(body);
  if (!parsed.ok) {
    return NextResponse.json(
      { error: "Invalid revenue record.", code: parsed.code },
      { status: 400 },
    );
  }

  const { input } = parsed;
  const recorded = await meterMoneyBestEffort({
    operation: `finance.${input.provider}.${input.metric}`,
    subject: { subjectKey: input.subjectKey },
    idempotencyKey: input.externalEventToken,
    metric: input.metric,
    amountMicroUsd: input.amountMicroUsd,
    resource:
      input.metric === "adjustments"
        ? "adjustment.correction"
        : input.provider === "stripe"
          ? "stripe.subscription"
          : "revenuecat.subscription",
    dimensions: { provider: input.provider },
    occurredAt: input.occurredAt,
  });
  if (!recorded) {
    return NextResponse.json(
      { error: "Revenue accounting failed.", code: "ACCOUNTING_FAILED" },
      { status: 503 },
    );
  }
  return NextResponse.json({ ok: true });
}
