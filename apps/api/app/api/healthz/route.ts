import { NextResponse } from "next/server";

export const runtime = "nodejs";

/** Shallow liveness probe for orchestrators — no database or Redis checks. */
export async function GET() {
  return NextResponse.json(
    {
      status: "ok",
      live: true,
    },
    {
      status: 200,
      headers: {
        "Cache-Control": "no-store",
      },
    },
  );
}
