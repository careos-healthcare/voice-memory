import {
  buildPatternEngineReport,
  type PatternInsightType,
} from "@/lib/patterns/pattern-engine";
import { formatEntryDate } from "@/lib/utils";
import type { EmergingPattern } from "@/types/blind-spot-acceleration";
import type { JournalEntry } from "@/types/journal";

const EMERGING_TYPES = new Set<PatternInsightType>([
  "contradiction",
  "avoidance_signal",
  "repeated_phrase",
  "recurring_pattern",
]);

function trimQuote(text: string): string {
  const n = text.replace(/\s+/g, " ").trim();
  return n.length <= 200 ? n : `${n.slice(0, 197)}…`;
}

function evidenceFromInsight(
  insight: { evidence: Array<{ entryId: string; dateLabel?: string; phrase: string }>; entryIds: string[] },
  entriesById: Map<string, JournalEntry>,
) {
  const fromInsight = insight.evidence
    .filter((e) => e.phrase?.trim())
    .map((e) => {
      const entry = entriesById.get(e.entryId);
      return {
        entryId: e.entryId,
        dateLabel: e.dateLabel ?? (entry ? formatEntryDate(entry.createdAt) : ""),
        quote: trimQuote(e.phrase),
      };
    });

  if (fromInsight.length >= 2) return fromInsight.slice(0, 3);

  const fallback = insight.entryIds.slice(0, 3).map((entryId) => {
    const entry = entriesById.get(entryId);
    if (!entry) return null;
    const quote = entry.transcript.trim().slice(0, 160);
    return {
      entryId,
      dateLabel: formatEntryDate(entry.createdAt),
      quote: trimQuote(quote),
    };
  });

  return fallback.filter(Boolean) as EmergingPattern["evidenceQuotes"];
}

function hypothesisFor(title: string): string {
  const cleaned = title.replace(/^You /i, "").trim();
  return `This may be starting to repeat in your archive: ${cleaned.charAt(0).toLowerCase()}${cleaned.slice(1)}`;
}

/** Surface low-confidence hypotheses after 2+ related reflections. */
export function buildEmergingPatterns(entries: JournalEntry[]): EmergingPattern[] {
  const eligible = entries.filter((e) => e.reflectionPending !== true);
  if (eligible.length < 2) return [];

  const report = buildPatternEngineReport(eligible, { scope: "archive", limit: 20 });
  const entriesById = new Map(eligible.map((e) => [e.id, e]));
  const patterns: EmergingPattern[] = [];

  for (const insight of report.insights) {
    if (!EMERGING_TYPES.has(insight.type)) continue;
    if (insight.entryIds.length < 2) continue;

    const evidenceQuotes = evidenceFromInsight(insight, entriesById);
    if (evidenceQuotes.length < 2) continue;

    patterns.push({
      id: `emerging:${insight.type}:${insight.sourceKey}`,
      label: "Possible emerging pattern",
      confidenceLabel: "Low confidence",
      hypothesis: hypothesisFor(insight.title),
      evidenceQuotes,
      matchingReflections: insight.entryIds.length,
    });

    if (patterns.length >= 3) break;
  }

  return patterns;
}
