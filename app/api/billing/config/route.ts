import { NextResponse } from "next/server";

import { getBillingPublicConfig } from "@/lib/billing/billing-public-config";

/** Public billing UI config — no secrets. */
export async function GET() {
  const config = await getBillingPublicConfig();
  return NextResponse.json(config);
}
