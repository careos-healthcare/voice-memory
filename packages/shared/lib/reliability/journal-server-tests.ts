import assert from "node:assert/strict";

import {
  deleteAllServerJournalEntries,
  exportServerJournal,
  upsertServerJournalEntries,
} from "@/lib/server/journal-store";
import type { JournalEntry } from "@/types/journal";

function sampleEntry(id: string): JournalEntry {
  return {
    id,
    createdAt: new Date().toISOString(),
    transcript: "test transcript",
    reflection: {
      mood: "calm",
      emotionalIntensity: 3,
      recurringThemes: [],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
    },
    durationSeconds: 12,
  };
}

export async function runJournalServerTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];
  const userId = `journal-test-${Date.now()}`;

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  await check("upsert and export", async () => {
    await upsertServerJournalEntries(userId, [
      { entry: sampleEntry("e1") },
      { entry: sampleEntry("e2") },
    ]);
    const exported = await exportServerJournal(userId);
    assert.equal(exported.length, 2);
    assert.ok(exported.some((e) => e.id === "e1"));
  });

  await check("delete all on account wipe path", async () => {
    const removed = await deleteAllServerJournalEntries(userId);
    assert.ok(removed >= 2);
    const after = await exportServerJournal(userId);
    assert.equal(after.length, 0);
  });

  return { failures };
}
