import assert from "node:assert/strict";

import {
  deleteAllServerJournalEntries,
  exportServerJournal,
  upsertServerJournalEntries,
} from "@/lib/server/journal-store";
import type { JournalEntry } from "@/types/journal";

function entry(id: string, iso: string): JournalEntry {
  return {
    id,
    createdAt: iso,
    transcript: "private text must not appear in logs",
    reflection: {
      mood: "",
      emotionalIntensity: 0,
      recurringThemes: [],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
    },
    durationSeconds: 5,
  };
}

export async function runJournalProductionTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];
  const userId = `journal-prod-${Date.now()}`;

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  await check("server upsert export delete wipe", async () => {
    await upsertServerJournalEntries(userId, [
      { entry: entry("a", "2026-01-01T10:00:00.000Z") },
      { entry: entry("b", "2026-01-02T10:00:00.000Z") },
    ]);
    const exported = await exportServerJournal(userId);
    assert.equal(exported.length, 2);
    const removed = await deleteAllServerJournalEntries(userId);
    assert.ok(removed >= 2);
    assert.equal((await exportServerJournal(userId)).length, 0);
  });

  await check("newer client_updated_at wins on upsert", async () => {
    await upsertServerJournalEntries(userId, [
      { entry: entry("c", "2026-01-01T10:00:00.000Z") },
    ]);
    await upsertServerJournalEntries(userId, [
      { entry: entry("c", "2026-01-05T10:00:00.000Z") },
    ]);
    const rows = await exportServerJournal(userId);
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.createdAt, "2026-01-05T10:00:00.000Z");
    await deleteAllServerJournalEntries(userId);
  });

  return { failures };
}
