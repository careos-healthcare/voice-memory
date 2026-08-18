import { formatConfidenceMovement } from "@/lib/theories/theory-confidence-movement";
import { sanitizeTheoryCopy } from "@/lib/theories/theory-copy";
import type { PersonalTheory, PersonalTheoryStatus } from "@/types/personal-theory";
import type { Theory, TheoryStatus } from "@/types/theory";

function mapStatus(status: TheoryStatus): PersonalTheoryStatus {
  switch (status) {
    case "strengthening":
      return "strengthening";
    case "weakening":
      return "weakening";
    case "resolved":
      return "resolved";
    case "retired":
      return "disproven";
    default:
      return "under_review";
  }
}

function titleFromStatement(statement: string): string {
  const trimmed = statement.replace(/\s+/g, " ").trim();
  if (trimmed.length <= 72) return trimmed;
  return `${trimmed.slice(0, 69)}…`;
}

function evidenceSummary(theory: Theory): string {
  const supporting = theory.supportingEvidenceCount;
  const contradicting = theory.contradictingEvidenceCount;
  if (supporting === 0 && contradicting === 0) {
    return "Not enough reflections linked yet to test this theory.";
  }
  if (contradicting > 0 && supporting > 0) {
    return `${supporting} supporting and ${contradicting} contradicting reflections in range.`;
  }
  if (contradicting > 0) {
    return `${contradicting} reflection${contradicting === 1 ? "" : "s"} may contradict this theory.`;
  }
  return `${supporting} reflection${supporting === 1 ? "" : "s"} currently support this theory.`;
}

function whyConfidenceChanged(theory: Theory): string {
  if (theory.whatChanged.length > 0) return theory.whatChanged[0]!;
  const movement = formatConfidenceMovement({
    delta: theory.confidenceDelta,
    previousConfidence: theory.previousConfidence,
    currentConfidence: theory.confidence,
  });
  if (movement.explanation) return movement.explanation;
  if (theory.confidenceDelta > 0) {
    return "New evidence may be supporting this theory.";
  }
  if (theory.confidenceDelta < 0) {
    return "Recent entries may be contradicting this theory.";
  }
  return "Confidence may shift as new reflections arrive.";
}

export function theoryToPersonalTheory(theory: Theory): PersonalTheory {
  const hypothesis = sanitizeTheoryCopy(theory.statement);
  return {
    id: theory.id,
    title: titleFromStatement(hypothesis),
    hypothesis,
    confidence: theory.confidence,
    status: mapStatus(theory.status),
    evidenceCount: theory.supportingEvidenceCount,
    contradictionCount: theory.contradictingEvidenceCount,
    lifeAreas: [],
    firstSeen: theory.createdAt,
    lastUpdated: theory.updatedAt,
    whyConfidenceChanged: whyConfidenceChanged(theory),
    evidenceSummary: evidenceSummary(theory),
    previousConfidence: theory.previousConfidence,
    confidenceDelta: theory.confidenceDelta,
  };
}
