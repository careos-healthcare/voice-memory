import assert from "node:assert/strict";

import { buildArchiveWorthSnapshot } from "@/lib/archive/archive-worth";
import { buildBeliefDossier } from "@/lib/archive/belief-dossier";
import { buildEvidenceLocker } from "@/lib/archive/evidence-locker";
import { canShowArchiveLossPrompt } from "@/lib/archive/archive-loss-prompt";
import { computeArchiveValueScoreFromInput } from "@/lib/archive/archive-value-score";
import { searchArchiveEvidence } from "@/lib/archive/evidence-search";
import { normalizeReflection } from "@/lib/reflection";
import type { JournalEntry } from "@/types/journal";

function sampleEntry(id: string, daysAgo: number, transcript: string): JournalEntry {
  return {
    id,
    createdAt: new Date(Date.now() - daysAgo * 86400000).toISOString(),
    transcript,
    durationSeconds: 45,
    reflection: normalizeReflection({
      mood: "anxious",
      emotionalIntensity: 6,
      recurringThemes: ["work"],
      hiddenConcern: "criticism",
      positiveSignal: "",
      recommendation: "",
    }),
  };
}

function installStorageMock(): void {
  const storage = new Map<string, string>();
  const localStorage = {
    getItem: (k: string) => storage.get(String(k)) ?? null,
    setItem: (k: string, v: string) => storage.set(String(k), String(v)),
    removeItem: (k: string) => storage.delete(String(k)),
    clear: () => storage.clear(),
    get length() {
      return storage.size;
    },
    key: (i: number) => [...storage.keys()][i] ?? null,
  };
  (globalThis as { window: Window }).window = {
    localStorage,
    location: { pathname: "/" },
  } as unknown as Window;
  (globalThis as { localStorage: Storage }).localStorage = localStorage as unknown as Storage;
}

export async function runArchiveValueDeepeningTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];
  installStorageMock();

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  const entries = [
    sampleEntry("e1", 20, "I spiralled after criticism at work again."),
    sampleEntry("e2", 15, "Same pattern when my manager emailed late."),
    sampleEntry("e3", 10, "I noticed I shut down before reading the full message."),
    sampleEntry("e4", 7, "Contradiction: I handled feedback calmly once."),
    sampleEntry("e5", 3, "The criticism spiral returned in another context."),
    sampleEntry("e6", 1, "Cost showed up as lost sleep after the thread."),
  ];

  await check("worth snapshot summarizes archive", () => {
    const worth = buildArchiveWorthSnapshot(entries);
    assert.ok(worth);
    assert.ok(worth.summaryLine.includes("reflection"));
    assert.equal(worth.headline, "Your archive would be hard to rebuild.");
  });

  await check("evidence locker caps at five", () => {
    const locker = buildEvidenceLocker(entries);
    assert.ok(locker.items.length <= 5);
    assert.ok(locker.items.every((i) => i.entryId));
  });

  await check("dossier includes revision lines", () => {
    const dossier = buildBeliefDossier(entries);
    assert.ok(dossier);
    assert.ok(dossier.whatWouldChangeLines.length >= 1);
  });

  await check("evidence search finds quote text", () => {
    const hits = searchArchiveEvidence("spiralled", entries);
    assert.ok(hits.length >= 1);
  });

  await check("value score stays internal range", () => {
    const { score } = computeArchiveValueScoreFromInput({
      reflectionCount: 6,
      daysCovered: 20,
      beliefsTracked: 2,
      beliefChangesRecorded: 1,
      evidenceQuotesStored: 8,
      contradictionCount: 1,
      costEvidenceCount: 1,
      recallStrongCount: 0,
      attachmentStrongCount: 0,
    });
    assert.ok(score >= 0 && score <= 100);
  });

  await check("loss prompt blocked when signed in", () => {
    assert.equal(canShowArchiveLossPrompt(true), false);
  });

  return { failures };
}
