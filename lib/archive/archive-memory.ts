import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveMemoryBeat, ArchiveMemoryView } from "@/types/living-archive";
import type { JournalEntry } from "@/types/journal";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function entriesBeforeDays(entries: JournalEntry[], days: number): JournalEntry[] {
  const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;
  return entries.filter((e) => new Date(e.createdAt).getTime() <= cutoff);
}

function beatFromEntries(
  label: ArchiveMemoryBeat["label"],
  entries: JournalEntry[],
): ArchiveMemoryBeat {
  const belief = buildArchiveBeliefView(entries);
  return {
    label,
    beliefLine: belief?.belief ?? "Still gathering evidence.",
    confidence: belief ? Math.round(belief.confidence) : null,
  };
}

export function buildArchiveMemory(entriesInput?: JournalEntry[]): ArchiveMemoryView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  if (entries.length < 2) return null;

  const today = beatFromEntries("Today", entries);
  const week = beatFromEntries("7 days ago", entriesBeforeDays(entries, 7));
  const month = beatFromEntries("30 days ago", entriesBeforeDays(entries, 30));

  const beats = [month, week, today];
  const lines = beats.map((b) => b.beliefLine.trim());
  const hasEvolution =
    lines[0] !== lines[2] ||
    (beats[0].confidence !== null &&
      beats[2].confidence !== null &&
      beats[0].confidence !== beats[2].confidence);

  return { beats, hasEvolution };
}
