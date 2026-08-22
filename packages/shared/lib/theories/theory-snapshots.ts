import type { TheorySnapshotRecord } from "@/types/theory";

const STORAGE_KEY = "voicememory_theory_snapshots";

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function readAll(): TheorySnapshotRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as TheorySnapshotRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeAll(records: TheorySnapshotRecord[]): void {
  getStorage()?.setItem(STORAGE_KEY, JSON.stringify(records.slice(-200)));
}

export function readTheorySnapshot(theoryId: string): TheorySnapshotRecord | undefined {
  return readAll().find((s) => s.theoryId === theoryId);
}

export function upsertTheorySnapshots(
  updates: Array<{
    theoryId: string;
    confidence: number;
    contradictingCount?: number;
  }>,
): void {
  const store = getStorage();
  if (!store) return;
  const now = new Date().toISOString();
  const byId = new Map(readAll().map((s) => [s.theoryId, s]));

  for (const { theoryId, confidence, contradictingCount } of updates) {
    byId.set(theoryId, {
      theoryId,
      confidence,
      contradictingCount,
      updatedAt: now,
    });
  }

  writeAll([...byId.values()]);
}

export function clearTheorySnapshotsForEval(): void {
  getStorage()?.removeItem(STORAGE_KEY);
}
