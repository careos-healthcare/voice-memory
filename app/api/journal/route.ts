import { NextResponse } from "next/server";

import {
  listServerJournalEntries,
  upsertServerJournalEntries,
} from "@/lib/server/journal-store";
import { getServerSession } from "@/lib/server/session";
import type { JournalEntry } from "@/types/journal";

export const runtime = "nodejs";

export async function GET() {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json(
      { error: "Sign in required.", code: "AUTH_REQUIRED" },
      { status: 401 },
    );
  }

  const rows = await listServerJournalEntries(session.userId);
  return NextResponse.json({
    entries: rows.map((r) => ({
      ...r.payload,
      _syncStatus: r.syncStatus,
      _serverUpdatedAt: r.updatedAt,
    })),
  });
}

export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json(
      { error: "Sign in required.", code: "AUTH_REQUIRED" },
      { status: 401 },
    );
  }

  let body: { entries?: JournalEntry[] };
  try {
    body = (await request.json()) as { entries?: JournalEntry[] };
  } catch {
    return NextResponse.json({ error: "Invalid body." }, { status: 400 });
  }

  const entries = body.entries ?? [];
  if (!Array.isArray(entries) || entries.length > 200) {
    return NextResponse.json(
      { error: "At most 200 entries per sync.", code: "BATCH_TOO_LARGE" },
      { status: 400 },
    );
  }

  const result = await upsertServerJournalEntries(
    session.userId,
    entries.map((entry) => ({ entry, syncStatus: "synced" })),
  );

  return NextResponse.json({ ok: true, upserted: result.upserted });
}
