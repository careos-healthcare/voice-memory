import { getMemoryEligibleEntries } from "@/lib/storage";
import {
  cleanupTranscript,
  TRANSCRIPT_CLEANUP_FIXTURES,
} from "@/lib/transcript/transcript-cleanup";
import type { TranscriptCleanupMeta, TranscriptCleanupResult } from "@/types/transcript-cleanup";

export interface TranscriptCleanupFixtureRow {
  label: string;
  raw: string;
  result: TranscriptCleanupResult;
}

export interface TranscriptCleanupEntryRow {
  entryId: string;
  createdAt: string;
  rawTranscript: string;
  cleanedTranscript: string;
  storedCleanup: TranscriptCleanupMeta | null;
  result: TranscriptCleanupResult;
}

export interface TranscriptCleanupDebugReport {
  generatedAt: string;
  hasData: boolean;
  fixtures: TranscriptCleanupFixtureRow[];
  entries: TranscriptCleanupEntryRow[];
  totals: {
    entriesWithRaw: number;
    entriesWithCleanupMeta: number;
    lowConfidence: number;
    preservedPhraseCount: number;
  };
}

export function buildTranscriptCleanupDebugReport(): TranscriptCleanupDebugReport {
  const fixtures = TRANSCRIPT_CLEANUP_FIXTURES.map((fixture) => ({
    label: fixture.label,
    raw: fixture.raw,
    result: cleanupTranscript(fixture.raw),
  }));

  const entries = getMemoryEligibleEntries()
    .slice(0, 16)
    .map((entry) => {
      const raw = entry.rawTranscript?.trim() || entry.transcript;
      const result = cleanupTranscript(raw);
      return {
        entryId: entry.id,
        createdAt: entry.createdAt,
        rawTranscript: raw,
        cleanedTranscript: entry.transcript,
        storedCleanup: entry.transcriptCleanup ?? null,
        result,
      };
    });

  const totals = {
    entriesWithRaw: entries.filter((row) => Boolean(row.storedCleanup) || row.rawTranscript !== row.cleanedTranscript).length,
    entriesWithCleanupMeta: entries.filter((row) => Boolean(row.storedCleanup)).length,
    lowConfidence: entries.filter((row) => row.result.confidence === "low").length,
    preservedPhraseCount: entries.reduce(
      (sum, row) => sum + row.result.preservedPhrases.length,
      0,
    ),
  };

  return {
    generatedAt: new Date().toISOString(),
    hasData: fixtures.length > 0 || entries.length > 0,
    fixtures,
    entries,
    totals,
  };
}
