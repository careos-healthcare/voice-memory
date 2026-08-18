import assert from "node:assert/strict";

import { estimateJournalBytes } from "@/lib/persistence/journal-indexeddb";
import type { JournalEntry } from "@/types/journal";

export function runJournalPersistenceTests(): { failures: string[] } {
  const failures: string[] = [];

  try {
    const entries: JournalEntry[] = [
      {
        id: "e1",
        createdAt: "2026-05-01T12:00:00.000Z",
        transcript: "test",
        durationSeconds: 1,
        reflection: {
          mood: "ok",
          emotionalIntensity: 5,
          recurringThemes: [],
          hiddenConcern: "",
          positiveSignal: "",
          recommendation: "",
        },
      },
    ];
    const bytes = estimateJournalBytes(entries);
    assert.ok(bytes > 0);
    assert.ok(bytes < 10_000);
  } catch (error) {
    failures.push(error instanceof Error ? error.message : String(error));
  }

  return { failures };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const result = runJournalPersistenceTests();
  if (result.failures.length > 0) {
    console.error("journal-persistence-tests failed:\n", result.failures.join("\n"));
    process.exit(1);
  }
  console.log("journal-persistence-tests ok");
}
