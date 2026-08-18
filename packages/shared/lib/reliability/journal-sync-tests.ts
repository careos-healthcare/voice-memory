import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";

import {
  getServerJournalEntry,
  listServerJournalEntries,
  listServerJournalEntriesPage,
  upsertServerJournalEntriesConditional,
} from "@/lib/server/journal-store";
import type { Reflection } from "@/types/journal";

/**
 * Server-side journal sync tests — conditional (conflict-aware) upsert,
 * tombstone propagation, ownership-spoofing defense, and batch semantics.
 * Mirrors the comparator contract implemented on mobile
 * (apps/mobile/lib/models/journal_entry.dart JournalSyncCompare).
 *
 * Note on tombstone retention/compaction: this suite intentionally does not
 * test a server-side compaction/retention job because none exists and none
 * is needed today — tombstoned journal rows are ordinary small JSONB/memory
 * rows with no storage-bloat problem that would justify a cron job, and a
 * full account deletion already removes every row (tombstoned or not) via
 * `deleteAllServerJournalEntries`. Retention/compaction of *locally* queued
 * pending-delete markers is a mobile-storage concern, not a server one.
 */

function baseReflection(): Reflection {
  return {
    mood: "calm",
    emotionalIntensity: 3,
    recurringThemes: [],
    hiddenConcern: "",
    positiveSignal: "",
    recommendation: "",
  };
}

function rawEntry(overrides: Record<string, unknown> & { id: string }): Record<string, unknown> {
  return {
    createdAt: new Date("2026-01-01T00:00:00.000Z").toISOString(),
    transcript: "test transcript",
    reflection: baseReflection(),
    durationSeconds: 12,
    ...overrides,
  };
}

export async function runJournalSyncTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  await check("edit after creation: revision 1 -> 2 accepted", async () => {
    const userId = `journal-sync-${randomUUID()}`;
    const id = "entry-1";
    const r1 = await upsertServerJournalEntriesConditional(userId, [
      rawEntry({ id, revision: 1, updatedAt: "2026-01-01T00:00:00.000Z" }),
    ]);
    assert.deepEqual(r1.accepted, [id]);
    assert.equal(r1.rejected.length, 0);

    const r2 = await upsertServerJournalEntriesConditional(userId, [
      rawEntry({
        id,
        revision: 2,
        updatedAt: "2026-01-01T01:00:00.000Z",
        transcript: "edited transcript",
      }),
    ]);
    assert.deepEqual(r2.accepted, [id]);

    const stored = await getServerJournalEntry(userId, id);
    assert.equal(stored?.payload.revision, 2);
    assert.equal(stored?.payload.transcript, "edited transcript");
  });

  await check("multiple offline edits: revision 1 -> 4 accepted", async () => {
    const userId = `journal-sync-${randomUUID()}`;
    const id = "entry-jump";
    await upsertServerJournalEntriesConditional(userId, [
      rawEntry({ id, revision: 1, updatedAt: "2026-01-01T00:00:00.000Z" }),
    ]);
    const jump = await upsertServerJournalEntriesConditional(userId, [
      rawEntry({ id, revision: 4, updatedAt: "2026-01-02T00:00:00.000Z" }),
    ]);
    assert.deepEqual(jump.accepted, [id]);
    const stored = await getServerJournalEntry(userId, id);
    assert.equal(stored?.payload.revision, 4);
  });

  await check("concurrent edits from two devices: later updatedAt wins", async () => {
    const userId = `journal-sync-${randomUUID()}`;
    const id = "entry-concurrent";
    await upsertServerJournalEntriesConditional(userId, [
      rawEntry({ id, revision: 1, updatedAt: "2026-01-01T00:00:00.000Z" }),
    ]);

    const deviceA = rawEntry({
      id,
      revision: 2,
      updatedAt: "2026-01-02T00:00:00.000Z",
      changeId: "device-a",
      transcript: "device A edit",
    });
    const deviceAResult = await upsertServerJournalEntriesConditional(userId, [deviceA]);
    assert.deepEqual(deviceAResult.accepted, [id]);

    const deviceB = rawEntry({
      id,
      revision: 2,
      updatedAt: "2026-01-03T00:00:00.000Z",
      changeId: "device-b",
      transcript: "device B edit",
    });
    const deviceBResult = await upsertServerJournalEntriesConditional(userId, [deviceB]);
    assert.deepEqual(deviceBResult.accepted, [id]);
    assert.equal(deviceBResult.rejected.length, 0);

    const stored = await getServerJournalEntry(userId, id);
    assert.equal(stored?.payload.transcript, "device B edit");

    // Resubmitting device A's now-stale edit must be rejected with device B's payload as the winner.
    const retryA = await upsertServerJournalEntriesConditional(userId, [deviceA]);
    assert.equal(retryA.accepted.length, 0);
    assert.equal(retryA.rejected.length, 1);
    assert.equal(retryA.rejected[0]?.reason, "STALE_REVISION");
    assert.equal(retryA.rejected[0]?.winning?.transcript, "device B edit");
  });

  await check("equal revision + equal updatedAt tie broken by changeId", async () => {
    const userId = `journal-sync-${randomUUID()}`;
    const id = "entry-tie";
    await upsertServerJournalEntriesConditional(userId, [
      rawEntry({ id, revision: 1, updatedAt: "2026-01-01T00:00:00.000Z" }),
    ]);
    const mid = rawEntry({
      id,
      revision: 2,
      updatedAt: "2026-01-02T00:00:00.000Z",
      changeId: "m",
    });
    const midResult = await upsertServerJournalEntriesConditional(userId, [mid]);
    assert.deepEqual(midResult.accepted, [id]);

    // Lexically-smaller changeId at the same revision+updatedAt must lose.
    const lower = await upsertServerJournalEntriesConditional(userId, [
      rawEntry({ id, revision: 2, updatedAt: "2026-01-02T00:00:00.000Z", changeId: "a" }),
    ]);
    assert.equal(lower.accepted.length, 0);
    assert.equal(lower.rejected[0]?.winning?.changeId, "m");

    // Lexically-greater changeId at the same revision+updatedAt must win.
    const higher = await upsertServerJournalEntriesConditional(userId, [
      rawEntry({ id, revision: 2, updatedAt: "2026-01-02T00:00:00.000Z", changeId: "z" }),
    ]);
    assert.deepEqual(higher.accepted, [id]);
    const stored = await getServerJournalEntry(userId, id);
    assert.equal(stored?.payload.changeId, "z");
  });

  await check("older upload rejection: revision 1 after server has revision 3", async () => {
    const userId = `journal-sync-${randomUUID()}`;
    const id = "entry-stale";
    await upsertServerJournalEntriesConditional(userId, [
      rawEntry({ id, revision: 1, updatedAt: "2026-01-01T00:00:00.000Z" }),
    ]);
    await upsertServerJournalEntriesConditional(userId, [
      rawEntry({ id, revision: 3, updatedAt: "2026-01-03T00:00:00.000Z" }),
    ]);

    const stale = await upsertServerJournalEntriesConditional(userId, [
      rawEntry({ id, revision: 1, updatedAt: "2026-01-01T00:00:00.000Z" }),
    ]);
    assert.equal(stale.accepted.length, 0);
    assert.equal(stale.rejected.length, 1);
    assert.equal(stale.rejected[0]?.reason, "STALE_REVISION");
    assert.equal(stale.rejected[0]?.winning?.revision, 3);
  });

  await check("local delete propagation: tombstone accepted and stored", async () => {
    const userId = `journal-sync-${randomUUID()}`;
    const id = "entry-delete";
    await upsertServerJournalEntriesConditional(userId, [
      rawEntry({ id, revision: 1, updatedAt: "2026-01-01T00:00:00.000Z" }),
    ]);
    const tombstone = await upsertServerJournalEntriesConditional(userId, [
      rawEntry({
        id,
        revision: 2,
        updatedAt: "2026-01-02T00:00:00.000Z",
        deletedAt: "2026-01-02T00:00:00.000Z",
      }),
    ]);
    assert.deepEqual(tombstone.accepted, [id]);

    const stored = await getServerJournalEntry(userId, id);
    assert.equal(stored?.payload.deletedAt, "2026-01-02T00:00:00.000Z");

    // Pull path must not filter tombstones out.
    const rows = await listServerJournalEntries(userId);
    const pulled = rows.find((r) => r.entryId === id);
    assert.ok(pulled, "tombstoned entry must still be returned by list/pull");
    assert.equal(pulled?.payload.deletedAt, "2026-01-02T00:00:00.000Z");
  });

  await check("remote delete propagation: deleted entry never resurrects from a stale edit", async () => {
    const userId = `journal-sync-${randomUUID()}`;
    const id = "entry-tombstone-stands";
    const tombstone = await upsertServerJournalEntriesConditional(userId, [
      rawEntry({
        id,
        revision: 5,
        updatedAt: "2026-01-05T00:00:00.000Z",
        deletedAt: "2026-01-05T00:00:00.000Z",
      }),
    ]);
    assert.deepEqual(tombstone.accepted, [id]);

    const staleResurrect = await upsertServerJournalEntriesConditional(userId, [
      rawEntry({
        id,
        revision: 3,
        updatedAt: "2026-01-03T00:00:00.000Z",
        transcript: "trying to undelete",
      }),
    ]);
    assert.equal(staleResurrect.accepted.length, 0);
    assert.equal(staleResurrect.rejected[0]?.winning?.deletedAt, "2026-01-05T00:00:00.000Z");

    const stored = await getServerJournalEntry(userId, id);
    assert.equal(stored?.payload.deletedAt, "2026-01-05T00:00:00.000Z");
  });

  await check(
    "a legitimately higher-revision non-deleted edit can undelete (symmetric comparator)",
    async () => {
      const userId = `journal-sync-${randomUUID()}`;
      const id = "entry-undelete";
      await upsertServerJournalEntriesConditional(userId, [
        rawEntry({
          id,
          revision: 2,
          updatedAt: "2026-01-02T00:00:00.000Z",
          deletedAt: "2026-01-02T00:00:00.000Z",
        }),
      ]);
      const undelete = await upsertServerJournalEntriesConditional(userId, [
        rawEntry({
          id,
          revision: 3,
          updatedAt: "2026-01-03T00:00:00.000Z",
          transcript: "restored on another device",
        }),
      ]);
      assert.deepEqual(undelete.accepted, [id]);
      const stored = await getServerJournalEntry(userId, id);
      assert.equal(stored?.payload.deletedAt, undefined);
    },
  );

  await check("all metadata survives sync round-trip byte-for-byte", async () => {
    const userId = `journal-sync-${randomUUID()}`;
    const rich = rawEntry({
      id: "entry-rich",
      revision: 1,
      updatedAt: "2026-01-01T00:00:00.000Z",
      changeId: "rich-change-id",
      schemaVersion: 2,
      isPinned: true,
      archiveThreadId: "thread-xyz",
      keepExactDetails: true,
      ownerKey: "some-owner-key",
      customMobileOnlyField: { nested: true, n: 42, list: [1, 2, 3] },
    });
    const result = await upsertServerJournalEntriesConditional(userId, [rich]);
    assert.deepEqual(result.accepted, ["entry-rich"]);

    const stored = await getServerJournalEntry(userId, "entry-rich");
    assert.ok(stored);
    for (const [key, value] of Object.entries(rich)) {
      assert.deepEqual(
        (stored!.payload as unknown as Record<string, unknown>)[key],
        value,
        `field ${key} must round-trip byte-for-byte`,
      );
    }
  });

  await check(
    "batch partial success: valid + invalid + conflicting entries resolved independently",
    async () => {
      const userId = `journal-sync-${randomUUID()}`;
      // Seed one entry at revision 3 so a later stale rev-1 push for the same id conflicts.
      await upsertServerJournalEntriesConditional(userId, [
        rawEntry({ id: "conflict-1", revision: 3, updatedAt: "2026-01-03T00:00:00.000Z" }),
      ]);

      const batch = [
        rawEntry({ id: "valid-1", revision: 1, updatedAt: "2026-01-01T00:00:00.000Z" }),
        rawEntry({ id: "valid-2", revision: 1, updatedAt: "2026-01-01T00:00:00.000Z" }),
        { createdAt: "2026-01-01T00:00:00.000Z", transcript: "no id" }, // missing id
        rawEntry({ id: "bad-date", revision: 1, createdAt: "not-a-date" }),
        rawEntry({ id: "bad-revision", revision: 0 }),
        rawEntry({ id: "conflict-1", revision: 1, updatedAt: "2026-01-01T00:00:00.000Z" }), // stale
      ];

      const result = await upsertServerJournalEntriesConditional(userId, batch);
      assert.deepEqual(result.accepted.sort(), ["valid-1", "valid-2"]);
      const rejectedIds = result.rejected.map((r) => r.id).sort();
      assert.deepEqual(rejectedIds, ["bad-date", "bad-revision", "conflict-1", "unknown"]);

      const reasons = Object.fromEntries(result.rejected.map((r) => [r.id, r.reason]));
      assert.equal(reasons["unknown"], "MISSING_ID");
      assert.equal(reasons["bad-date"], "INVALID_CREATED_AT");
      assert.equal(reasons["bad-revision"], "INVALID_REVISION");
      assert.equal(reasons["conflict-1"], "STALE_REVISION");
    },
  );

  await check("retry after partial batch success: only genuinely-winning entries accepted", async () => {
    const userId = `journal-sync-${randomUUID()}`;
    await upsertServerJournalEntriesConditional(userId, [
      rawEntry({ id: "retry-a", revision: 3, updatedAt: "2026-01-03T00:00:00.000Z" }),
      rawEntry({ id: "retry-b", revision: 1, updatedAt: "2026-01-01T00:00:00.000Z" }),
    ]);

    // Client resubmits the same batch: retry-a's local copy (revision 2) is stale;
    // retry-b's local copy (revision 2) genuinely wins over stored revision 1.
    const retry = await upsertServerJournalEntriesConditional(userId, [
      rawEntry({ id: "retry-a", revision: 2, updatedAt: "2026-01-02T00:00:00.000Z" }),
      rawEntry({ id: "retry-b", revision: 2, updatedAt: "2026-01-02T00:00:00.000Z" }),
    ]);
    assert.deepEqual(retry.accepted, ["retry-b"]);
    assert.equal(retry.rejected.length, 1);
    assert.equal(retry.rejected[0]?.id, "retry-a");
    assert.equal(retry.rejected[0]?.winning?.revision, 3);

    // A genuine follow-up edit for retry-a (revision 4) now wins.
    const followUp = await upsertServerJournalEntriesConditional(userId, [
      rawEntry({ id: "retry-a", revision: 4, updatedAt: "2026-01-04T00:00:00.000Z" }),
    ]);
    assert.deepEqual(followUp.accepted, ["retry-a"]);
  });

  await check("ownership spoofing: embedded userId field is ignored", async () => {
    const sessionUserId = `journal-sync-owner-${randomUUID()}`;
    const otherUserId = `journal-sync-victim-${randomUUID()}`;
    const spoofed = rawEntry({
      id: "entry-spoof",
      revision: 1,
      updatedAt: "2026-01-01T00:00:00.000Z",
      userId: otherUserId,
      accountId: otherUserId,
    });

    const result = await upsertServerJournalEntriesConditional(sessionUserId, [spoofed]);
    assert.deepEqual(result.accepted, ["entry-spoof"]);

    const storedForSession = await getServerJournalEntry(sessionUserId, "entry-spoof");
    assert.ok(storedForSession, "entry must be stored under the session's userId");
    assert.equal(
      (storedForSession!.payload as unknown as Record<string, unknown>).userId,
      undefined,
      "spoofed ownership field must be stripped from the stored payload",
    );

    const storedForOther = await getServerJournalEntry(otherUserId, "entry-spoof");
    assert.equal(storedForOther, null, "spoofed userId must never redirect storage to another account");
  });

  await check(
    "deterministic pull pagination: pages never skip or duplicate a row across a large journal",
    async () => {
      const userId = `journal-sync-${randomUUID()}`;
      const total = 23;
      for (let i = 0; i < total; i += 1) {
        await upsertServerJournalEntriesConditional(userId, [
          rawEntry({
            id: `page-entry-${i}`,
            revision: 1,
            // Several entries deliberately share the same updatedAt so the
            // entryId tie-break is actually exercised, not just the common case.
            updatedAt: `2026-01-0${1 + (i % 3)}T00:00:00.000Z`,
          }),
        ]);
      }

      const seenIds: string[] = [];
      let cursor = null as Awaited<ReturnType<typeof listServerJournalEntriesPage>>["nextCursor"];
      let iterations = 0;
      do {
        const page = await listServerJournalEntriesPage(userId, { limit: 5, cursor });
        assert.ok(
          page.rows.length <= 5,
          "a page must never exceed the requested limit",
        );
        seenIds.push(...page.rows.map((r) => r.entryId));
        cursor = page.nextCursor;
        iterations += 1;
        assert.ok(iterations <= total, "pagination must terminate");
      } while (cursor !== null);

      assert.equal(seenIds.length, total, "every entry must be returned exactly once across pages");
      assert.equal(
        new Set(seenIds).size,
        total,
        "no entry may be duplicated across pages",
      );

      const fullPull = await listServerJournalEntries(userId);
      assert.deepEqual(
        seenIds.sort(),
        fullPull.map((r) => r.entryId).sort(),
        "paginated pull must return the same overall set as the unbounded pull",
      );
    },
  );

  await check(
    "pull pagination: a limit larger than the journal returns everything in one page",
    async () => {
      const userId = `journal-sync-${randomUUID()}`;
      await upsertServerJournalEntriesConditional(userId, [
        rawEntry({ id: "solo-1", revision: 1, updatedAt: "2026-01-01T00:00:00.000Z" }),
        rawEntry({ id: "solo-2", revision: 1, updatedAt: "2026-01-02T00:00:00.000Z" }),
      ]);
      const page = await listServerJournalEntriesPage(userId, { limit: 500 });
      assert.equal(page.rows.length, 2);
      assert.equal(page.nextCursor, null);
    },
  );

  await check("legacy entry without sync fields defaults to schema v1 and is never rejected", async () => {
    const userId = `journal-sync-${randomUUID()}`;
    const legacy: Record<string, unknown> = {
      id: "legacy-entry",
      createdAt: "2026-01-01T00:00:00.000Z",
      transcript: "pre-migration client",
      reflection: baseReflection(),
      durationSeconds: 8,
      // no updatedAt / revision / changeId / schemaVersion
    };
    const result = await upsertServerJournalEntriesConditional(userId, [legacy]);
    assert.deepEqual(result.accepted, ["legacy-entry"]);

    const stored = await getServerJournalEntry(userId, "legacy-entry");
    assert.equal(stored?.payload.revision, 1);
    assert.equal(stored?.payload.updatedAt, "2026-01-01T00:00:00.000Z");
    assert.ok(typeof stored?.payload.changeId === "string" && stored.payload.changeId.length > 0);
  });

  return { failures };
}
