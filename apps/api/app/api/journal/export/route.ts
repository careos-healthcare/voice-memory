import { NextResponse } from "next/server";

import { apiErrorResponse } from "@/lib/server/api-error-response";
import { exportServerJournal } from "@/lib/server/journal-store";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

export async function GET() {
  const session = await getServerSession();
  if (!session) {
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "journal/export",
    });
  }

  const entries = await exportServerJournal(session.userId);
  return NextResponse.json({
    exportedAt: new Date().toISOString(),
    count: entries.length,
    entries,
  });
}
