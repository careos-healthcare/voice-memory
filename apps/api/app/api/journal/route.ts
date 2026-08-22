import { NextResponse } from "next/server";

import {
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import {
  JOURNAL_SYNC_BATCH_LIMIT,
  listServerJournalEntries,
  listServerJournalEntriesPage,
  upsertServerJournalEntriesConditional,
} from "@/lib/server/journal-store";
import type { JournalPageCursor } from "@/lib/server/journal-store";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

/** Opaque wire format for a pull-pagination cursor — base64 JSON, never interpreted client-side. */
function encodeCursor(cursor: JournalPageCursor): string {
  return Buffer.from(JSON.stringify(cursor), "utf8").toString("base64url");
}

function decodeCursor(raw: string | null): JournalPageCursor | null {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(Buffer.from(raw, "base64url").toString("utf8"));
    if (
      parsed &&
      typeof parsed === "object" &&
      typeof parsed.clientUpdatedAt === "string" &&
      typeof parsed.entryId === "string"
    ) {
      return { clientUpdatedAt: parsed.clientUpdatedAt, entryId: parsed.entryId };
    }
  } catch {
    // Malformed/tampered cursor — treated as "start from the beginning" below.
  }
  return null;
}

/**
 * Pull path for journal sync. Deliberately does NOT filter out tombstoned
 * entries (payload.deletedAt set) — mobile needs to pull tombstones so a
 * deletion on one device propagates to every other device on next sync.
 * Hiding deleted entries from the archive UI is a client-side concern.
 *
 * Pagination is opt-in via `?limit=`: omitting it preserves the original,
 * unbounded full-pull response for backward compatibility. A client that
 * wants deterministic, boundable page sizes (an account with a very large
 * journal) passes `limit` and, on subsequent calls, the `nextCursor` this
 * endpoint returned — ordering is total (server `updatedAt` DESC, `entryId`
 * DESC tie-break) so pages never skip or duplicate a row.
 */
export async function GET(request: Request) {
  const session = await getServerSession();
  if (!session) {
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "journal",
    });
  }

  const url = new URL(request.url);
  const limitParam = url.searchParams.get("limit");

  if (limitParam !== null) {
    const limit = Number.parseInt(limitParam, 10);
    if (!Number.isFinite(limit) || limit < 1) {
      return apiErrorResponse({ code: "INVALID_LIMIT", route: "journal" });
    }
    const cursor = decodeCursor(url.searchParams.get("cursor"));
    const page = await listServerJournalEntriesPage(session.userId, { limit, cursor });
    return NextResponse.json({
      entries: page.rows.map((r) => ({
        ...r.payload,
        _syncStatus: r.syncStatus,
        _serverUpdatedAt: r.updatedAt,
      })),
      nextCursor: page.nextCursor ? encodeCursor(page.nextCursor) : null,
    });
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
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "journal",
    });
  }

  let body: { entries?: unknown };
  try {
    body = (await request.json()) as { entries?: unknown };
  } catch {
    return apiErrorResponse({
      code: "INVALID_BODY",
      route: "journal",
      internalCategory: "validation",
    });
  }

  const entries = body.entries;
  if (!Array.isArray(entries)) {
    return apiErrorResponse({
      code: "INVALID_BODY",
      route: "journal",
      internalCategory: "validation",
    });
  }
  if (entries.length > JOURNAL_SYNC_BATCH_LIMIT) {
    return apiErrorResponse({ code: "BATCH_TOO_LARGE", route: "journal" });
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
