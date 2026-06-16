import { ARCHIVE_EMOTIONAL } from "@/lib/archive/archive-emotional-copy";
import type { ArchiveBeliefView } from "@/types/archive-belief";

const COACHING_PATTERN =
  /\b(should|try to|consider|recommend|therapy|diagnos|advice|you need to|work on)\b/i;

function singleSentence(text: string): string {
  const one = text.replace(/\s+/g, " ").trim();
  const first = one.split(/(?<=[.!?])\s+/)[0] ?? one;
  return first.endsWith(".") ? first : `${first}.`;
}

function beliefToHumanSees(belief: string): string | null {
  const raw = belief.replace(/\s+/g, " ").trim();
  if (!raw || COACHING_PATTERN.test(raw)) return null;

  const lower = raw.toLowerCase();
  if (
    lower.includes("criticism") &&
    (lower.includes("weight") || lower.includes("expect") || lower.includes("carry"))
  ) {
    return "For now, your archive sees criticism as carrying more weight than you expect.";
  }

  const clause = raw.split(/[.;]/)[0]!.trim();
  const cleaned = clause
    .replace(/^(you may|you might|it seems (?:that )?|perhaps)\s+/i, "")
    .replace(/^you\s+/i, "")
    .replace(/\.$/, "");

  if (cleaned.length < 12 || COACHING_PATTERN.test(cleaned)) return null;

  const body =
    cleaned.charAt(0).toLowerCase() + cleaned.slice(1);
  return singleSentence(`For now, your archive sees ${body}`);
}

/**
 * One human sentence after belief / timeline / evidence — never coaching or advice.
 */
export function buildArchiveMeaningSummary(view: ArchiveBeliefView): string {
  if (view.confidence < 50 || view.status === "under_review") {
    return ARCHIVE_EMOTIONAL.notCertainYet;
  }

  const hasContradiction = view.evidence.contradictingQuotes.length > 0;
  const shifting =
    view.status === "weakening" ||
    view.status === "strengthening" ||
    hasContradiction ||
    view.changeLines.length >= 2;

  if (shifting && view.confidence < 72) {
    return ARCHIVE_EMOTIONAL.stillChanging;
  }

  const human = beliefToHumanSees(view.belief);
  if (human) return human;

  if (shifting) return ARCHIVE_EMOTIONAL.stillChanging;
  if (view.confidence < 65) return ARCHIVE_EMOTIONAL.notCertainYet;

  return singleSentence(
    `For now, your archive holds this view: ${view.belief.replace(/\s+/g, " ").trim()}`,
  );
}
