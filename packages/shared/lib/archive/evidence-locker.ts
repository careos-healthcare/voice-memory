import {
  buildDiscoverEvidenceContext,
  theoryToEvidenceBaseline,
} from "@/lib/discover/theory-evidence-snapshot";
import { linkedAreasForEntries } from "@/lib/blind-spots/blind-spot-ranking";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { theoryToPersonalTheory } from "@/lib/theories/personal-theory-map";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { EvidenceLockerItem, EvidenceLockerTag, EvidenceLockerView } from "@/types/evidence-locker";
import type { JournalEntry } from "@/types/journal";
import type { Theory, TheoryEvidenceQuote } from "@/types/theory";

export const EVIDENCE_LOCKER_TITLE = "Evidence locker";
export const EVIDENCE_LOCKER_SUBTITLE =
  "These are the pieces of evidence your archive would lose.";

const TAG_PRIORITY: Record<EvidenceLockerTag, number> = {
  contradicts: 1,
  cost: 2,
  "cross-area": 3,
  prediction: 4,
  supports: 5,
};

function itemId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

function whyForTag(tag: EvidenceLockerTag, beliefText: string): string {
  switch (tag) {
    case "contradicts":
      return "Contradiction your archive is holding against the current belief.";
    case "cost":
      return "Cost signal tied to what this belief would mean if it held.";
    case "cross-area":
      return "Same pattern showing up across more than one life area.";
    case "prediction":
      return "A prediction the archive tracked that later reflections did not match.";
    default:
      return `Supporting line the archive uses for: ${beliefText.slice(0, 80)}${beliefText.length > 80 ? "…" : ""}`;
  }
}

function pushQuote(
  rows: EvidenceLockerItem[],
  theory: Theory,
  quote: TheoryEvidenceQuote,
  tag: EvidenceLockerTag,
  lifeAreaCount: number,
): void {
  const beliefText = theoryToPersonalTheory(theory).hypothesis;
  let resolvedTag = tag;
  if (tag === "supports" && lifeAreaCount >= 2) {
    resolvedTag = "cross-area";
  }
  if (theory.source === "prediction" && tag === "supports") {
    resolvedTag = "prediction";
  }

  rows.push({
    id: itemId("el"),
    quote: quote.quote,
    entryId: quote.entryId,
    dateLabel: quote.dateLabel,
    beliefText,
    theoryId: theory.id,
    tag: resolvedTag,
    whyItMatters: whyForTag(resolvedTag, beliefText),
    sortPriority: TAG_PRIORITY[resolvedTag],
  });
}

export function buildEvidenceLocker(entriesInput?: JournalEntry[]): EvidenceLockerView {
  const entries = (entriesInput ?? getMemoryEligibleEntries()).filter(
    (e) => e.reflectionPending !== true,
  );
  const items: EvidenceLockerItem[] = [];

  if (entries.length === 0) {
    return { title: EVIDENCE_LOCKER_TITLE, subtitle: EVIDENCE_LOCKER_SUBTITLE, items: [] };
  }

  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const context = buildDiscoverEvidenceContext(entries);

  for (const theory of report.all) {
    const entryIds = [
      ...new Set([
        ...theory.supportingEvidence.map((q) => q.entryId),
        ...theory.contradictingEvidence.map((q) => q.entryId),
      ]),
    ];
    const lifeAreaCount = linkedAreasForEntries(context.eligible, entryIds).length;

    for (const q of theory.contradictingEvidence) {
      pushQuote(items, theory, q, "contradicts", lifeAreaCount);
    }

    const baseline = theoryToEvidenceBaseline(theory, entries, context);
    if (baseline.costEvidenceLines.length > 0) {
      for (const q of theory.supportingEvidence.slice(0, 2)) {
        if (!items.some((i) => i.entryId === q.entryId && i.quote === q.quote)) {
          pushQuote(items, theory, q, "cost", lifeAreaCount);
        }
      }
    }

    for (const q of theory.supportingEvidence) {
      if (items.some((i) => i.entryId === q.entryId && i.quote === q.quote)) continue;
      pushQuote(items, theory, q, "supports", lifeAreaCount);
    }
  }

  const sorted = items
    .slice()
    .sort((a, b) => a.sortPriority - b.sortPriority || b.quote.length - a.quote.length);

  return {
    title: EVIDENCE_LOCKER_TITLE,
    subtitle: EVIDENCE_LOCKER_SUBTITLE,
    items: sorted.slice(0, 5),
  };
}
