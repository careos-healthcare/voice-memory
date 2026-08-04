import { NextResponse } from "next/server";

import {
  authorizeRevenueCatWebhook,
  processRevenueCatWebhook,
} from "@/lib/server/revenuecat-webhook-handler";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const authorization = authorizeRevenueCatWebhook(
    request.headers.get("authorization"),
  );
  if (authorization) {
    return NextResponse.json(
      { error: "RevenueCat webhook rejected.", code: authorization.code },
      { status: authorization.status },
    );
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return NextResponse.json(
      {
        error: "RevenueCat webhook payload is invalid.",
        code: "REVENUECAT_WEBHOOK_INVALID",
      },
      { status: 400 },
    );
  }
  const result = await processRevenueCatWebhook(payload);
  if (!result.ok) {
    return NextResponse.json(
      { error: "RevenueCat webhook could not be applied.", code: result.code },
      { status: result.status },
    );
  }
  return NextResponse.json({
    received: true,
    duplicate: result.duplicate,
    ignored: result.ignored,
  });
}
