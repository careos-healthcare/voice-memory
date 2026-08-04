import { NextResponse } from "next/server";

export const runtime = "nodejs";

export async function POST() {
  return NextResponse.json(
    {
      error: "New subscriptions are available in the ArchiveMe mobile app.",
      code: "MOBILE_STORE_PURCHASE_REQUIRED",
    },
    { status: 410 },
  );
}
