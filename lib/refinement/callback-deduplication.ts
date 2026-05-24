import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { CallbackDeduplicationReport, CallbackStructurePattern } from "@/types/emotional-integrity-layer";

const STRUCTURE_PATTERNS: Array<{ id: string; pattern: RegExp; label: string }> = [
  { id: "sound_different_now", pattern: /\bsound different\b/i, label: "You sound different" },
  { id: "changed_later", pattern: /\b(changed|change) later\b/i, label: "This changed later" },
  { id: "you_sound", pattern: /\byou sound\b/i, label: "You sound…" },
  { id: "before_things", pattern: /\bbefore things\b/i, label: "Before things settled" },
  { id: "returned_here", pattern: /\breturned here\b/i, label: "Returned here" },
  { id: "came_back", pattern: /\bcame back\b/i, label: "Came back" },
  { id: "heavier_stretch", pattern: /\bheavier stretch\b/i, label: "Heavier stretch" },
  { id: "settled_down", pattern: /\bsettled down\b/i, label: "Settled down" },
];

const MAX_SAME_STRUCTURE = 2;

function detectPatterns(entries: JournalEntry[]): CallbackStructurePattern[] {
  const report = buildCallbackQualityReviewReport(entries);
  const patterns: CallbackStructurePattern[] = [];

  for (const { id, pattern, label } of STRUCTURE_PATTERNS) {
    const matches = report.items.filter((item) => pattern.test(item.text));
    if (matches.length === 0) continue;
    patterns.push({
      id,
      pattern: pattern.source,
      label,
      count: matches.length,
      examples: matches.slice(0, 3).map((m) => m.text.slice(0, 100)),
    });
  }

  return patterns.sort((a, b) => b.count - a.count);
}

/** Prevent emotional callback structures from collapsing into templates. */
export function buildCallbackDeduplicationReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): CallbackDeduplicationReport {
  const patterns = detectPatterns(entries);
  const report = buildCallbackQualityReviewReport(entries);

  const collapsedTemplates = patterns
    .filter((p) => p.count >= MAX_SAME_STRUCTURE + 1)
    .map((p) => `${p.label} (${p.count}×)`);

  const suppressionCandidates = report.items
    .filter((item) => {
      const lower = item.text.toLowerCase();
      const overloaded = patterns.some(
        (p) => p.count > MAX_SAME_STRUCTURE && new RegExp(p.pattern, "i").test(item.text),
      );
      return overloaded || item.rewriteFlags.includes("could_apply_to_many");
    })
    .slice(0, 10)
    .map((item) => ({
      id: item.id,
      text: item.text.slice(0, 120),
      reason: "Repeated emotional structure or template phrasing",
    }));

  return {
    generatedAt: new Date().toISOString(),
    hasData: patterns.length > 0,
    patterns,
    collapsedTemplates,
    suppressionCandidates,
  };
}

/** Returns callback ids that should be deprioritized due to structural repetition. */
export function deprioritizeRepeatedStructureIds(
  candidateIds: string[],
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): Set<string> {
  const report = buildCallbackDeduplicationReport(entries);
  const suppressed = new Set<string>();

  for (const pattern of report.patterns) {
    if (pattern.count <= MAX_SAME_STRUCTURE) continue;
    const re = new RegExp(pattern.pattern, "i");
    const reportItems = buildCallbackQualityReviewReport(entries).items.filter(
      (item) => candidateIds.includes(item.id) && re.test(item.text),
    );
    for (const item of reportItems.slice(MAX_SAME_STRUCTURE)) {
      suppressed.add(item.id);
    }
  }

  return suppressed;
}

export function passesStructureDeduplication(text: string, entries?: JournalEntry[]): boolean {
  const patterns = detectPatterns(entries ?? getMemoryEligibleEntries());
  for (const pattern of patterns) {
    if (pattern.count <= MAX_SAME_STRUCTURE) continue;
    if (new RegExp(pattern.pattern, "i").test(text)) return false;
  }
  return true;
}
