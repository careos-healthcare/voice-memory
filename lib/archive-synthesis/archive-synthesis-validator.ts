import type {
  ArchiveDeepDiveNarrative,
  ArchiveHistorianReport,
  ArchiveMilestoneReview,
  ArchiveMonthlyReview,
  ArchiveSynthesisConclusion,
  ArchiveSynthesisPack,
} from "@/types/archive-synthesis";
import {
  buildPackCanonicalSourceMap,
  findBannedInText,
  validateConclusion,
  validateConclusionSection,
  validateOptionalConclusion,
} from "@/lib/archive-synthesis/archive-synthesis-common";

export function validateArchiveMonthlyReview(
  review: ArchiveMonthlyReview,
  pack: ArchiveSynthesisPack,
): { ok: true } | { ok: false; errors: string[] } {
  const sources = buildPackCanonicalSourceMap(pack);
  const errors: string[] = [];
  if (review.reviewVersion !== 4) errors.push("reviewVersion: V4 required");

  errors.push(
    ...validateConclusionSection(review.whatChanged, sources, "whatChanged"),
    ...validateConclusionSection(
      review.emergingTheories,
      sources,
      "emergingTheories",
    ),
    ...validateConclusionSection(
      review.fadingTheories,
      sources,
      "fadingTheories",
    ),
    ...validateConclusionSection(review.surprises, sources, "surprises"),
    ...validateConclusionSection(review.evidenceFor, sources, "evidenceFor"),
    ...validateConclusionSection(
      review.evidenceAgainst,
      sources,
      "evidenceAgainst",
    ),
    ...validateOptionalConclusion(
      review.biggestSurprise,
      sources,
      "biggestSurprise",
    ),
    ...validateOptionalConclusion(
      review.strongestContradiction,
      sources,
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
  const sources = buildPackCanonicalSourceMap(pack);
  const errors: string[] = [];
  if (review.reviewVersion !== 4) errors.push("reviewVersion: V4 required");

  errors.push(...findBannedInText(review.headline, "headline"));
  errors.push(...findBannedInText(review.narrative, "narrative"));
  errors.push(...findBannedInText(review.uncertaintyNote, "uncertaintyNote"));
  errors.push(
    ...validateConclusion(
      review.primaryTheorySummary,
      sources,
      "primaryTheorySummary",
    ),
    ...validateConclusionSection(
      review.changeHighlights,
      sources,
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
  const sources = buildPackCanonicalSourceMap(pack);
  const errors: string[] = [];
  if (review.reviewVersion !== 4) errors.push("reviewVersion: V4 required");

  errors.push(...findBannedInText(review.narrativeExplanation, "narrative"));
  errors.push(...findBannedInText(review.uncertaintyNote, "uncertaintyNote"));
  errors.push(
    ...validateConclusion(
      review.beliefEvolutionSummary,
      sources,
      "beliefEvolutionSummary",
    ),
    ...validateConclusionSection(
      review.evidenceSynthesis,
      sources,
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
  const sources = buildPackCanonicalSourceMap(pack);
  const errors: string[] = [];
  if (review.reviewVersion !== 4) errors.push("reviewVersion: V4 required");

  errors.push(...findBannedInText(review.title, "title"));
  errors.push(...findBannedInText(review.uncertaintyNote, "uncertaintyNote"));
  errors.push(
    ...validateConclusionSection(review.timeline, sources, "timeline"),
  );

  if (errors.length > 0) return { ok: false, errors };
  return { ok: true };
}

function parseConclusions(
  raw: unknown,
  key: string,
): ArchiveSynthesisConclusion[] {
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
  if (parsed.reviewVersion !== 4) {
    throw new Error("Invalid synthesis JSON: reviewVersion must be 4");
  }
  parsed.biggestSurprise = parseOptionalConclusion(parsed, "biggestSurprise");
  parsed.strongestContradiction = parseOptionalConclusion(
    parsed,
    "strongestContradiction",
  );
  return parsed;
}

export function parseArchiveMilestoneReview(
  raw: string,
): ArchiveMilestoneReview {
  const parsed = JSON.parse(raw) as ArchiveMilestoneReview;
  if (!parsed.milestoneThreshold || !parsed.archiveHash) {
    throw new Error("Invalid milestone JSON");
  }
  if (parsed.reviewVersion !== 4) {
    throw new Error("Invalid milestone JSON: reviewVersion must be 4");
  }
  return parsed;
}

export function parseArchiveDeepDiveNarrative(
  raw: string,
): ArchiveDeepDiveNarrative {
  const parsed = JSON.parse(raw) as ArchiveDeepDiveNarrative;
  if (!parsed.beliefStatement || !parsed.archiveHash) {
    throw new Error("Invalid deep dive narrative JSON");
  }
  if (parsed.reviewVersion !== 4) {
    throw new Error("Invalid deep dive JSON: reviewVersion must be 4");
  }
  return parsed;
}

export function parseArchiveHistorianReport(
  raw: string,
): ArchiveHistorianReport {
  const parsed = JSON.parse(raw) as ArchiveHistorianReport;
  if (!parsed.monthKey || !parsed.archiveHash) {
    throw new Error("Invalid historian JSON");
  }
  if (parsed.reviewVersion !== 4) {
    throw new Error("Invalid historian JSON: reviewVersion must be 4");
  }
  return parsed;
}
