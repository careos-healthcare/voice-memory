import type {
  ArchiveDeepDiveNarrative,
  ArchiveHistorianReport,
  ArchiveMilestoneReview,
  ArchiveMonthlyReview,
  ArchiveSynthesisConclusion,
  ArchiveSynthesisPack,
} from "@/types/archive-synthesis";
import {
  collectPackEntryIds,
  findBannedInText,
  validateConclusion,
  validateConclusionSection,
  validateOptionalConclusion,
} from "@/lib/archive-synthesis/archive-synthesis-common";

export function validateArchiveMonthlyReview(
  review: ArchiveMonthlyReview,
  pack: ArchiveSynthesisPack,
): { ok: true } | { ok: false; errors: string[] } {
  const allowedIds = collectPackEntryIds(pack);
  const errors: string[] = [];

  errors.push(
    ...validateConclusionSection(review.whatChanged, allowedIds, "whatChanged"),
    ...validateConclusionSection(
      review.emergingTheories,
      allowedIds,
      "emergingTheories",
    ),
    ...validateConclusionSection(
      review.fadingTheories,
      allowedIds,
      "fadingTheories",
    ),
    ...validateConclusionSection(review.surprises, allowedIds, "surprises"),
    ...validateConclusionSection(review.evidenceFor, allowedIds, "evidenceFor"),
    ...validateConclusionSection(
      review.evidenceAgainst,
      allowedIds,
      "evidenceAgainst",
    ),
    ...validateOptionalConclusion(
      review.biggestSurprise,
      allowedIds,
      "biggestSurprise",
    ),
    ...validateOptionalConclusion(
      review.strongestContradiction,
      allowedIds,
      "strongestContradiction",
    ),
  );

  if (errors.length > 0) return { ok: false, errors };
  return { ok: true };
}

export function validateArchiveMilestoneReview(
  review: ArchiveMilestoneReview,
  pack: ArchiveSynthesisPack,
): { ok: true } | { ok: false; errors: string[] } {
  const allowedIds = collectPackEntryIds(pack);
  const errors: string[] = [];

  errors.push(...findBannedInText(review.headline, "headline"));
  errors.push(...findBannedInText(review.narrative, "narrative"));
  errors.push(...findBannedInText(review.uncertaintyNote, "uncertaintyNote"));
  errors.push(
    ...validateConclusion(
      review.primaryTheorySummary,
      allowedIds,
      "primaryTheorySummary",
    ),
    ...validateConclusionSection(
      review.changeHighlights,
      allowedIds,
      "changeHighlights",
    ),
  );

  if (errors.length > 0) return { ok: false, errors };
  return { ok: true };
}

export function validateArchiveDeepDiveNarrative(
  review: ArchiveDeepDiveNarrative,
  pack: ArchiveSynthesisPack,
): { ok: true } | { ok: false; errors: string[] } {
  const allowedIds = collectPackEntryIds(pack);
  const errors: string[] = [];

  errors.push(...findBannedInText(review.narrativeExplanation, "narrative"));
  errors.push(...findBannedInText(review.uncertaintyNote, "uncertaintyNote"));
  errors.push(
    ...validateConclusion(
      review.beliefEvolutionSummary,
      allowedIds,
      "beliefEvolutionSummary",
    ),
    ...validateConclusionSection(
      review.evidenceSynthesis,
      allowedIds,
      "evidenceSynthesis",
    ),
  );

  if (errors.length > 0) return { ok: false, errors };
  return { ok: true };
}

export function validateArchiveHistorianReport(
  review: ArchiveHistorianReport,
  pack: ArchiveSynthesisPack,
): { ok: true } | { ok: false; errors: string[] } {
  const allowedIds = collectPackEntryIds(pack);
  const errors: string[] = [];

  errors.push(...findBannedInText(review.title, "title"));
  errors.push(...findBannedInText(review.uncertaintyNote, "uncertaintyNote"));
  errors.push(
    ...validateConclusionSection(review.timeline, allowedIds, "timeline"),
  );

  if (errors.length > 0) return { ok: false, errors };
  return { ok: true };
}

function parseConclusions(raw: unknown, key: string): ArchiveSynthesisConclusion[] {
  const section = (raw as Record<string, unknown>)[key];
  if (!Array.isArray(section)) {
    throw new Error(`Invalid synthesis JSON: ${key} must be array`);
  }
  return section as ArchiveSynthesisConclusion[];
}

function parseOptionalConclusion(
  raw: unknown,
  key: string,
): ArchiveSynthesisConclusion | null {
  const item = (raw as Record<string, unknown>)[key];
  if (item == null) return null;
  return item as ArchiveSynthesisConclusion;
}

export function parseArchiveMonthlyReview(raw: string): ArchiveMonthlyReview {
  const parsed = JSON.parse(raw) as ArchiveMonthlyReview;
  if (!parsed.monthKey || !parsed.archiveHash) {
    throw new Error("Invalid synthesis JSON: missing monthKey or archiveHash");
  }
  const sections = [
    "whatChanged",
    "emergingTheories",
    "fadingTheories",
    "surprises",
    "evidenceFor",
    "evidenceAgainst",
  ] as const;
  for (const key of sections) {
    parseConclusions(parsed, key);
  }
  parsed.reviewVersion = 2;
  parsed.biggestSurprise = parseOptionalConclusion(parsed, "biggestSurprise");
  parsed.strongestContradiction = parseOptionalConclusion(
    parsed,
    "strongestContradiction",
  );
  return parsed;
}

export function parseArchiveMilestoneReview(raw: string): ArchiveMilestoneReview {
  const parsed = JSON.parse(raw) as ArchiveMilestoneReview;
  if (!parsed.milestoneThreshold || !parsed.archiveHash) {
    throw new Error("Invalid milestone JSON");
  }
  parsed.reviewVersion = 2;
  return parsed;
}

export function parseArchiveDeepDiveNarrative(
  raw: string,
): ArchiveDeepDiveNarrative {
  const parsed = JSON.parse(raw) as ArchiveDeepDiveNarrative;
  if (!parsed.beliefStatement || !parsed.archiveHash) {
    throw new Error("Invalid deep dive narrative JSON");
  }
  parsed.reviewVersion = 2;
  return parsed;
}

export function parseArchiveHistorianReport(raw: string): ArchiveHistorianReport {
  const parsed = JSON.parse(raw) as ArchiveHistorianReport;
  if (!parsed.monthKey || !parsed.archiveHash) {
    throw new Error("Invalid historian JSON");
  }
  parsed.reviewVersion = 2;
  return parsed;
}
