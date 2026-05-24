import { buildArchiveGravityReport } from "@/lib/refinement/archive-gravity";
import { entryRevisitRewardCandidates } from "@/lib/refinement/knows-me-moments";
import {
  assessFalsePositive,
  sourceModuleFromNoteId,
} from "@/lib/refinement/false-positive-suppression";
import { buildMemoryNotesReport } from "@/lib/patterns/memory-notes";
import { buildDelayedPayoffReport } from "@/lib/memory/delayed-payoff";
import { buildEmotionalChapterReport } from "@/lib/memory/emotional-chapters";
import { buildLivingResurfacingReport } from "@/lib/memory/living-resurfacing";
import { buildResurfacingReport } from "@/lib/memory/resurfacing";
import { voiceIdentityDebugCandidates } from "@/lib/memory/voice-identity";
import type { FalsePositiveSourceModule } from "@/types/false-positive-suppression";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type {
  SuppressionReviewItem,
  SuppressionReviewReport,
} from "@/types/suppression-review";

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function toNote(
  input: {
    id: string;
    text: string;
    strength?: number;
    confidence?: number;
    pastQuote?: string;
    currentQuote?: string;
    pastEntryId?: string;
    entryId?: string;
  },
  sourceModule: FalsePositiveSourceModule,
): { note: MemoryNote; sourceModule: FalsePositiveSourceModule } {
  return {
    sourceModule,
    note: {
      id: input.id,
      text: input.text,
      category: "changed",
      confidence: input.confidence ?? input.strength ?? 0,
      pastQuote: input.pastQuote,
      currentQuote: input.currentQuote,
      pastEntryId: input.pastEntryId,
      entryId: input.entryId,
    },
  };
}

function reviewNote(
  note: MemoryNote,
  entries: JournalEntry[],
  sourceModule: FalsePositiveSourceModule,
): SuppressionReviewItem {
  const verdict = assessFalsePositive({ note, entries, sourceModule });
  return {
    id: note.id,
    text: note.text,
    sourceModule,
    suppressed: verdict.suppressed,
    reasons: verdict.reasons,
    missingEvidence: verdict.missingEvidence,
    candidateText: note.text,
    hierarchyScore: verdict.hierarchyScore,
  };
}

function collectCandidates(entries: JournalEntry[]): Array<{
  note: MemoryNote;
  sourceModule: FalsePositiveSourceModule;
}> {
  const sorted = sortedEntries(entries);
  const collected: Array<{ note: MemoryNote; sourceModule: FalsePositiveSourceModule }> = [];

  const memoryReport = buildMemoryNotesReport(sorted);
  for (const note of memoryReport.all) {
    collected.push({ note, sourceModule: sourceModuleFromNoteId(note.id) });
  }

  const resurfacing = buildResurfacingReport(sorted, { limit: 24, surface: "memory" });
  for (const row of resurfacing.notes) {
    collected.push(
      toNote(
        {
          id: row.id,
          text: row.text,
          strength: row.strength,
          pastQuote: row.pastQuote,
          currentQuote: row.currentQuote,
          pastEntryId: row.pastEntryId,
          entryId: row.entryId,
        },
        "resurfacing",
      ),
    );
  }

  const latest = sorted[sorted.length - 1];
  if (latest) {
    for (const note of entryRevisitRewardCandidates(sorted, latest.id)) {
      collected.push({ note, sourceModule: "revisit_reward" });
    }
  }

  for (const surface of ["homepage", "memory", "timeline", "monthly"] as const) {
    for (const row of buildArchiveGravityReport(sorted, surface).candidates) {
      collected.push(
        toNote(
          {
            id: row.id,
            text: row.text,
            strength: row.strength,
            pastQuote: row.pastQuote,
            currentQuote: row.currentQuote,
            pastEntryId: row.pastEntryId,
            entryId: row.entryId,
          },
          "archive_gravity",
        ),
      );
    }
  }

  for (const row of buildLivingResurfacingReport(sorted, "memory").candidates) {
    collected.push(
      toNote(
        {
          id: row.id,
          text: row.text,
          strength: row.strength,
          pastQuote: row.pastQuote,
          currentQuote: row.currentQuote,
          pastEntryId: row.pastEntryId,
          entryId: row.entryId,
        },
        "living_resurfacing",
      ),
    );
  }

  for (const note of voiceIdentityDebugCandidates(sorted)) {
    collected.push({ note, sourceModule: "voice_identity" });
  }

  for (const row of buildEmotionalChapterReport(sorted, undefined, 58).candidates) {
    collected.push(
      toNote(
        {
          id: row.id,
          text: row.text,
          strength: row.strength,
          pastQuote: row.pastQuote,
          currentQuote: row.currentQuote,
          pastEntryId: row.pastEntryId,
          entryId: row.entryId,
        },
        "chaptering",
      ),
    );
  }

  for (const row of buildDelayedPayoffReport(sorted).candidates) {
    collected.push(
      toNote(
        {
          id: row.id,
          text: row.text,
          strength: row.strength,
          pastQuote: row.pastQuote,
          currentQuote: row.currentQuote,
          pastEntryId: row.pastEntryId,
          entryId: row.entryId,
        },
        "delayed_payoff",
      ),
    );
  }

  const seen = new Set<string>();
  return collected.filter(({ note }) => {
    const key = `${note.id}:${note.text}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

export function buildSuppressionReviewReport(
  entries: JournalEntry[],
): SuppressionReviewReport {
  if (entries.length === 0) {
    return {
      hasData: false,
      totalCandidates: 0,
      suppressedCount: 0,
      surfacedCount: 0,
      byReason: {},
      items: [],
    };
  }

  const candidates = collectCandidates(entries);
  const items = candidates.map(({ note, sourceModule }) =>
    reviewNote(note, entries, sourceModule),
  );

  const byReason: SuppressionReviewReport["byReason"] = {};
  for (const item of items) {
    for (const reason of item.reasons) {
      byReason[reason] = (byReason[reason] ?? 0) + 1;
    }
  }

  const suppressedCount = items.filter((item) => item.suppressed).length;

  return {
    hasData: true,
    totalCandidates: items.length,
    suppressedCount,
    surfacedCount: items.length - suppressedCount,
    byReason,
    items: items.sort(
      (a, b) =>
        Number(b.suppressed) - Number(a.suppressed) ||
        b.reasons.length - a.reasons.length,
    ),
  };
}
