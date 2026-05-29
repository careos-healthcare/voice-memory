import { NextResponse } from "next/server";

import { exportServerJournal } from "@/lib/server/journal-store";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

export async function GET() {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json(
      { error: "Sign in required.", code: "AUTH_REQUIRED" },
      { status: 401 },
    );
  }

  const entries = await exportServerJournal(session.userId);
  return NextResponse.json({
    exportedAt: new Date().toISOString(),
    count: entries.length,
    entries,
  });
}
