import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { theoryToPersonalTheory } from "@/lib/theories/personal-theory-map";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { EvidenceSearchHit } from "@/types/evidence-search";
import type { JournalEntry } from "@/types/journal";

function formatDateLabel(iso: string): string {
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(new Date(iso));
}

function matchesQuery(text: string, q: string): boolean {
  return text.toLowerCase().includes(q);
}

export function searchArchiveEvidence(
  query: string,
  entriesInput?: JournalEntry[],
  limit = 12,
): EvidenceSearchHit[] {
  const q = query.trim().toLowerCase();
  if (q.length < 2) return [];

  const entries = (entriesInput ?? getMemoryEligibleEntries()).filter(
    (e) => e.reflectionPending !== true,
  );
  const hits: EvidenceSearchHit[] = [];
  const seen = new Set<string>();

  const belief = buildArchiveBeliefView(entries);
  if (belief && matchesQuery(belief.belief, q)) {
    hits.push({
      id: `belief-${belief.theoryId}`,
      quote: belief.belief,
      beliefText: belief.belief,
      entryId: "",
      dateLabel: "",
      lifeAreas: belief.evidence.lifeAreas,
      matchSource: "belief",
    });
  }

  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  for (const theory of report.all) {
    const beliefText = theoryToPersonalTheory(theory).hypothesis;
    for (const quote of [
      ...theory.supportingEvidence,
      ...theory.contradictingEvidence,
    ]) {
      const key = `${quote.entryId}:${quote.quote}`;
      if (seen.has(key)) continue;
      if (!matchesQuery(quote.quote, q) && !matchesQuery(beliefText, q)) continue;
      seen.add(key);
      hits.push({
        id: key,
        quote: quote.quote,
        beliefText,
        entryId: quote.entryId,
        dateLabel: quote.dateLabel,
        lifeAreas: [],
        matchSource: "quote",
      });
    }
  }

  for (const entry of entries) {
    const snippet =
      entry.transcript?.trim().slice(0, 280) ||
      entry.reflection?.mood ||
      "";
    if (!snippet || !matchesQuery(snippet, q)) continue;
    const key = `entry-${entry.id}`;
    if (seen.has(key)) continue;
    seen.add(key);
    hits.push({
      id: key,
      quote: snippet.length > 200 ? `${snippet.slice(0, 200)}…` : snippet,
      beliefText: belief?.belief ?? "Saved moment",
      entryId: entry.id,
      dateLabel: formatDateLabel(entry.createdAt),
      lifeAreas: entry.reflection.recurringThemes?.slice(0, 3) ?? [],
      matchSource: "reflection",
    });
  }

  return hits.slice(0, limit);
}
