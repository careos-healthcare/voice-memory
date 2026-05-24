import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildCallbackDeduplicationReport } from "@/lib/refinement/callback-deduplication";
import { evaluateAntiTemplate } from "@/lib/refinement/anti-template";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { RarityPreservationReport, RarityPreservationRow } from "@/types/sacredness-layer";

function structuralRarity(text: string, patterns: ReturnType<typeof buildCallbackDeduplicationReport>["patterns"]): number {
  let rarity = 70;
  for (const pattern of patterns) {
    if (new RegExp(pattern.pattern, "i").test(text)) {
      rarity -= pattern.count * 8;
    }
  }
  return Math.max(0, rarity);
}

/** Protect rare callbacks — suppress overused emotional templates. */
export function buildRarityPreservationReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): RarityPreservationReport {
  const callbacks = buildCallbackQualityReviewReport(entries);
  const dedup = buildCallbackDeduplicationReport(entries);

  const rows: RarityPreservationRow[] = callbacks.items.map((item) => {
    const anti = evaluateAntiTemplate(item.text);
    const structureRarity = structuralRarity(item.text, dedup.patterns);
    const unusualWording = item.manualLabels.includes("emotionally_precise") ? 15 : 0;
    const asymmetric = item.emotionalWeight >= 70 && item.survival.emotionalSurvivalScore < 40 ? 12 : 0;
    const infrequentStyle = item.rewriteFlags.includes("could_apply_to_many") ? -20 : 10;

    const rarityScore = Math.min(
      100,
      Math.max(0, structureRarity + unusualWording + asymmetric + infrequentStyle - (anti.suppressed ? 30 : 0)),
    );

    const overloaded = dedup.patterns.some(
      (p) => p.count >= 3 && new RegExp(p.pattern, "i").test(item.text),
    );

    const protectedRow =
      rarityScore >= 55 &&
      !overloaded &&
      !anti.suppressed &&
      (item.doubleDown || item.survival.emotionalSurvivalScore >= 45);

    let reason = "Standard surfacing";
    if (protectedRow) reason = "Rare structure or asymmetric moment";
    else if (overloaded) reason = "Overused emotional template";
    else if (anti.suppressed) reason = anti.warning ?? "Template-like";

    return {
      id: item.id,
      text: item.text.slice(0, 100),
      rarityScore,
      protected: protectedRow,
      reason,
    };
  });

  return {
    generatedAt: new Date().toISOString(),
    hasData: rows.length > 0,
    protectedRows: rows.sort((a, b) => b.rarityScore - a.rarityScore).slice(0, 16),
    suppressedTemplateCount: rows.filter((r) => r.reason.includes("template") || r.reason.includes("Template")).length,
  };
}

export function isRarityProtected(noteId: string, entries?: JournalEntry[]): boolean {
  const report = buildRarityPreservationReport(entries);
  return report.protectedRows.some((r) => r.id === noteId && r.protected);
}

export function filterRarityPreservedIds(candidateIds: string[], entries?: JournalEntry[]): Set<string> {
  const report = buildRarityPreservationReport(entries);
  const protectedIds = new Set(report.protectedRows.filter((r) => r.protected).map((r) => r.id));
  return new Set(candidateIds.filter((id) => protectedIds.has(id) || !report.protectedRows.find((r) => r.id === id)));
}

export function shouldSuppressForRarity(text: string, entries?: JournalEntry[]): boolean {
  const dedup = buildCallbackDeduplicationReport(entries);
  const anti = evaluateAntiTemplate(text);
  if (anti.suppressed) return true;
  return dedup.patterns.some((p) => p.count >= 3 && new RegExp(p.pattern, "i").test(text));
}
