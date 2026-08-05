import { NextResponse } from "next/server";

import {
  deleteServerJournalEntry,
  upsertServerJournalEntriesConditional,
} from "@/lib/server/journal-store";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

/**
 * Single-entry conditional push — same conflict-aware upsert path as the
 * bulk `POST /api/journal` route (see lib/server/journal-store.ts), scoped
 * to one entry. This is how an ordinary "user deleted this entry" sync
 * should be communicated: push the entry again with `deletedAt` set (a
 * tombstone) rather than calling DELETE below. A tombstone is just another
 * revision, so it wins or loses against the stored copy via the normal
 * revision/updatedAt/changeId comparison — a later non-deleted edit with a
 * genuinely higher revision can "undelete" only if it legitimately wins.
 *
 * Contract note for the mobile side: as of this change, the mobile
 * SyncService (apps/voicememory_mobile/lib/services/sync_service.dart) and
 * ApiClient.deleteJournalEntry (apps/voicememory_mobile/lib/api/api_client.dart)
 * still call DELETE directly for local deletions — they have not yet been
 * wired to push a tombstone via this PUT route using
 * `JournalEntry.markDeleted()`. That mobile-side wiring is a follow-up; this
 * endpoint is ready for it today.
 */
export async function PUT(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json(
      { error: "Sign in required.", code: "AUTH_REQUIRED" },
      { status: 401 },
    );
  }

  const { id } = await context.params;

  let body: { entry?: unknown };
  try {
    body = (await request.json()) as { entry?: unknown };
  } catch {
    return NextResponse.json(
      { error: "Invalid body.", code: "INVALID_BODY" },
      { status: 400 },
    );
  }

  const entry = body.entry;
  if (!entry || typeof entry !== "object") {
    return NextResponse.json(
      { error: "entry is required.", code: "INVALID_BODY" },
      { status: 400 },
    );
  }

  const entryId = (entry as { id?: unknown }).id;
  if (typeof entryId !== "string" || entryId.trim() === "" || entryId !== id) {
    return NextResponse.json(
      { error: "entry.id must match the route id.", code: "ID_MISMATCH" },
      { status: 400 },
    );
  }

  const report = await upsertServerJournalEntriesConditional(session.userId, [entry]);

  return NextResponse.json({
    ok: true,
    accepted: report.accepted,
    rejected: report.rejected,
  });
}

/**
 * Hard purge — removes the row entirely with no tombstone left behind for
 * other devices to pull. This remains available for account-level/legacy
 * cleanup, but ordinary client-driven "user deleted this entry" sync must go
 * through PUT above instead, so the deletion propagates to other devices via
 * the normal pull (a hard delete here is invisible to a device that hasn't
 * seen it yet — there's nothing to pull).
 */
export async function DELETE(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json(
      { error: "Sign in required.", code: "AUTH_REQUIRED" },
      { status: 401 },
    );
  }

  const { id } = await context.params;
  const removed = await deleteServerJournalEntry(session.userId, id);
  if (!removed) {
    return NextResponse.json({ error: "Not found." }, { status: 404 });
  }
  return NextResponse.json({ ok: true });
}
