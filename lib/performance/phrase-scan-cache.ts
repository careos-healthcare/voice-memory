import { measurePerf } from "@/lib/performance/perf-instrumentation";
import type { PhraseMemoryRecord } from "@/lib/patterns/phrase-memory";
import type { JournalEntry } from "@/types/journal";

let cacheVersion = 0;
let cachedVersion = -1;
let cachedKey = "";
let cachedPhrases: PhraseMemoryRecord[] = [];

function entriesFingerprint(entries: JournalEntry[]): string {
  if (entries.length === 0) return "0";
  const head = entries[0]?.id ?? "";
  const tail = entries[entries.length - 1]?.id ?? "";
  return `${entries.length}:${head}:${tail}:${entries[0]?.createdAt ?? ""}`;
}

export function bumpPhraseScanCache(): void {
  cacheVersion += 1;
}

export function getCachedPhraseMemory(
  entries: JournalEntry[],
  builder: (rows: JournalEntry[]) => PhraseMemoryRecord[],
): PhraseMemoryRecord[] {
  const key = `${cacheVersion}:${entriesFingerprint(entries)}`;
  if (key === cachedKey && cachedVersion === cacheVersion) {
    return cachedPhrases;
  }
  cachedPhrases = measurePerf("phrase_memory_scan", () => builder(entries));
  cachedKey = key;
  cachedVersion = cacheVersion;
  return cachedPhrases;
}
