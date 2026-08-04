import type {
  ArchiveSynthesisConclusion,
  ArchiveSynthesisPack,
} from "@/types/archive-synthesis";
import { findBannedPhrase } from "@/lib/archive-synthesis/archive-synthesis-banned";
import { validateExplainableConclusion } from "@/lib/explainability/validate-explainable-conclusion";
import type { CanonicalTranscriptSourceMap } from "@/types/explainability";

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

export function buildPackCanonicalSourceMap(
  pack: ArchiveSynthesisPack,
): Map<string, string> {
  return new Map(
    pack.reflectionIndex.flatMap((entry) =>
      typeof entry.canonicalTranscript === "string"
        ? [[entry.id, entry.canonicalTranscript] as const]
        : [],
    ),
  );
}

export function validateConclusion(
  item: ArchiveSynthesisConclusion,
  sources: CanonicalTranscriptSourceMap,
  path: string,
): string[] {
  const errors = validateExplainableConclusion(item, sources, path).errors;
  if (!item || typeof item !== "object") return errors;
  if (
    !Number.isInteger(item.confidence) ||
    item.confidence !== item.confidencePercent
  ) {
    errors.push(`${path}: confidence must equal confidencePercent`);
  }
  if (
    !Array.isArray(item.reasoning) ||
    item.reasoning.length === 0 ||
    item.reasoning.some(
      (step) => typeof step !== "string" || step.trim().length < 8,
    )
  ) {
    errors.push(`${path}: step-by-step reasoning required`);
  }
  if (
    !item.alternativeExplanation ||
    item.alternativeExplanation.statement !==
      item.alternatives?.[0]?.statement ||
    item.alternativeExplanation.reason !== item.alternatives?.[0]?.reason
  ) {
    errors.push(
      `${path}: alternativeExplanation must equal the primary alternative`,
    );
  }
  if (
    typeof item.uncertainty !== "string" ||
    item.uncertainty !== item.uncertaintyNote
  ) {
    errors.push(`${path}: uncertainty must equal uncertaintyNote`);
  }
  if (
    item.provenance?.schemaVersion !== 4 ||
    item.provenance?.promptVersion !== "archive-explainable-v2"
  ) {
    errors.push(`${path}: V4 provenance required`);
  }
  const banned = findBannedPhrase(
    `${item?.statement ?? ""} ${item?.reasoning?.join(" ") ?? ""} ${
      item?.alternativeExplanation?.statement ?? ""
    } ${item?.alternativeExplanation?.reason ?? ""} ${
      item?.uncertaintyNote ?? ""
    }`,
  );
  if (banned) errors.push(`${path}: banned phrase "${banned}"`);
  for (const ev of Array.isArray(item.evidence) ? item.evidence : []) {
    const b = findBannedPhrase(ev.quote);
    if (b) errors.push(`${path}: banned evidence phrase "${b}"`);
  }
  return errors;
}

export function validateConclusionSection(
  items: ArchiveSynthesisConclusion[],
  sources: CanonicalTranscriptSourceMap,
  section: string,
): string[] {
  if (!Array.isArray(items)) return [`${section}: must be an array`];
  return items.flatMap((item, i) =>
    validateConclusion(item, sources, `${section}[${i}]`),
  );
}

export function validateOptionalConclusion(
  item: ArchiveSynthesisConclusion | null | undefined,
  sources: CanonicalTranscriptSourceMap,
  path: string,
): string[] {
  if (item == null) return [];
  return validateConclusion(item, sources, path);
}

export function findBannedInText(text: string, path: string): string[] {
  const banned = findBannedPhrase(text);
  return banned ? [`${path}: banned phrase "${banned}"`] : [];
}
