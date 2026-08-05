import { NextResponse } from "next/server";

import {
  JOURNAL_SYNC_BATCH_LIMIT,
  listServerJournalEntries,
  upsertServerJournalEntriesConditional,
} from "@/lib/server/journal-store";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

/**
 * Pull path for journal sync. Deliberately does NOT filter out tombstoned
 * entries (payload.deletedAt set) — mobile needs to pull tombstones so a
 * deletion on one device propagates to every other device on next sync.
 * Hiding deleted entries from the archive UI is a client-side concern.
 */
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

/**
 * Bulk push path for journal sync. Every entry goes through the same
 * conditional (conflict-aware) upsert, including entries that carry a
 * `deletedAt` tombstone — a delete is just another revision here, so it is
 * subject to the exact same revision/updatedAt/changeId comparison as any
 * edit. A single invalid or losing entry never fails the rest of the batch;
 * only a malformed request body or an oversized batch fails the whole call.
 */
export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json(
      { error: "Sign in required.", code: "AUTH_REQUIRED" },
      { status: 401 },
    );
  }

  let body: { entries?: unknown };
  try {
    body = (await request.json()) as { entries?: unknown };
  } catch {
    return NextResponse.json(
      { error: "Invalid body.", code: "INVALID_BODY" },
      { status: 400 },
    );
  }

  const entries = body.entries;
  if (!Array.isArray(entries)) {
    return NextResponse.json(
      { error: "entries must be an array.", code: "INVALID_BODY" },
      { status: 400 },
    );
  }
  if (entries.length > JOURNAL_SYNC_BATCH_LIMIT) {
    return NextResponse.json(
      { error: "At most 200 entries per sync.", code: "BATCH_TOO_LARGE" },
      { status: 400 },
    );
  }

  const report = await upsertServerJournalEntriesConditional(session.userId, entries);

  return NextResponse.json({
    ok: true,
    accepted: report.accepted,
    rejected: report.rejected,
    // Backward-compatible count field for any older client that only reads this.
    upserted: report.accepted.length,
  });
}
