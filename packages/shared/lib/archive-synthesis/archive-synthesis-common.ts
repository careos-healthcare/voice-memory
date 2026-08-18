import type {
  ArchiveSynthesisConclusion,
  ArchiveSynthesisPack,
} from "@/types/archive-synthesis";
import { findBannedPhrase } from "@/lib/archive-synthesis/archive-synthesis-banned";

export function collectPackEntryIds(pack: ArchiveSynthesisPack): Set<string> {
  const ids = new Set<string>();
  for (const r of pack.reflectionIndex) ids.add(r.id);
  for (const c of pack.contradictions) {
    for (const id of c.entryIds) ids.add(id);
  }
  for (const b of pack.blindSpots) {
    for (const id of b.entryIds) ids.add(id);
  }
  for (const s of pack.surprises) {
    for (const id of s.evidenceEntryIds) ids.add(id);
  }
  for (const e of pack.evidenceTrails.forExcerpts) ids.add(e.entryId);
  for (const e of pack.evidenceTrails.againstExcerpts) ids.add(e.entryId);
  if (pack.deepDiveContext) {
    for (const id of pack.deepDiveContext.excerptEntryIds) ids.add(id);
  }
  return ids;
}

export function validateConclusion(
  item: ArchiveSynthesisConclusion,
  allowedIds: Set<string>,
  path: string,
): string[] {
  const errors: string[] = [];
  if (!item.statement?.trim()) errors.push(`${path}: empty statement`);
  if (!item.uncertaintyNote?.trim()) {
    errors.push(`${path}: missing uncertaintyNote`);
  }
  if (item.confidencePercent < 0 || item.confidencePercent > 100) {
    errors.push(`${path}: confidence out of range`);
  }
  const banned = findBannedPhrase(
    `${item.statement} ${item.uncertaintyNote}`,
  );
  if (banned) errors.push(`${path}: banned phrase "${banned}"`);
  if (!item.evidence?.length) {
    errors.push(`${path}: evidence required`);
  }
  for (const ev of item.evidence ?? []) {
    if (!allowedIds.has(ev.entryId)) {
      errors.push(`${path}: unknown entryId ${ev.entryId}`);
    }
    if (ev.excerpt) {
      const b = findBannedPhrase(ev.excerpt);
      if (b) errors.push(`${path}: banned excerpt phrase "${b}"`);
    }
  }
  return errors;
}

export function validateConclusionSection(
  items: ArchiveSynthesisConclusion[],
  allowedIds: Set<string>,
  section: string,
): string[] {
  return items.flatMap((item, i) =>
    validateConclusion(item, allowedIds, `${section}[${i}]`),
  );
}

export function validateOptionalConclusion(
  item: ArchiveSynthesisConclusion | null | undefined,
  allowedIds: Set<string>,
  path: string,
): string[] {
  if (item == null) return [];
  return validateConclusion(item, allowedIds, path);
}

export function findBannedInText(text: string, path: string): string[] {
  const banned = findBannedPhrase(text);
  return banned ? [`${path}: banned phrase "${banned}"`] : [];
}

/** Theory pack keys removed from LLM input when theory tracking is disabled. */
const THEORY_PACK_KEYS = [
  "primaryTheory",
  "secondaryTheories",
  "theory",
] as const;

type TheoryPackKey = (typeof THEORY_PACK_KEYS)[number];

/**
 * Strips theory-ranking fields from client packs when theory tracking is off so
 * they never reach synthesis prompts, validation, or cache keys.
 */
export function stripLegacyTheoryPackFields(
  pack: ArchiveSynthesisPack & Partial<Record<TheoryPackKey, unknown>>,
): ArchiveSynthesisPack {
  if (process.env.VOICEMEMORY_ENABLE_THEORY_TRACKING === "true") {
    return pack;
  }
  const sanitized = { ...pack };
  for (const key of THEORY_PACK_KEYS) {
    delete sanitized[key];
  }
  return sanitized;
}

/** Whether the pack includes ranked theory data for synthesis. */
export function packHasTheoryTracking(pack: ArchiveSynthesisPack): boolean {
  return pack.primaryTheory != null;
}

/** Pack payload sent to the LLM (theory fields removed when tracking is off). */
export function packForLlmSynthesis(
  pack: ArchiveSynthesisPack,
): ArchiveSynthesisPack {
  return stripLegacyTheoryPackFields(
    pack as ArchiveSynthesisPack & Partial<Record<TheoryPackKey, unknown>>,
  );
}
