import { validateExplainableConclusion } from "@/lib/explainability/validate-explainable-conclusion";
import { parseActiveHypotheses } from "@/lib/explainability/hypothesis-evolution-contract";
import { parseTruthAnchors } from "@/lib/ai/truth-anchor-context";
import type {
  WeeklyDeltaDimension,
  WeeklyIntelligenceSynthesisRequest,
  WeeklyIntelligenceSynthesisResult,
} from "@/types/weekly-intelligence-synthesis";

const DIMENSIONS = new Set<WeeklyDeltaDimension>([
  "action_intent_ratio",
  "emotional_velocity",
  "habit_drift",
  "relationship_dynamics",
  "identity_shift",
]);

export function parseWeeklyIntelligenceRequest(
  value: unknown,
): WeeklyIntelligenceSynthesisRequest {
  if (!isRecord(value)) throw new Error("Request must be an object");
  const weekStart = date(value.weekStart, "weekStart");
  const weekEnd = date(value.weekEnd, "weekEnd");
  if (
    typeof value.userId !== "string" ||
    !value.userId ||
    weekStart >= weekEnd ||
    !Number.isInteger(value.baselineWeekCount) ||
    Number(value.baselineWeekCount) < 1 ||
    !Array.isArray(value.localDeltas) ||
    !Array.isArray(value.evidence)
  ) {
    throw new Error("Invalid weekly intelligence request");
  }
  const evidence = value.evidence.map((item) => {
    if (
      !isRecord(item) ||
      typeof item.sourceEntryId !== "string" ||
      !item.sourceEntryId ||
      (item.week !== "baseline" && item.week !== "current") ||
      typeof item.canonicalTranscript !== "string" ||
      !item.canonicalTranscript ||
      (item.audioTimestampMs != null &&
        (!Number.isInteger(item.audioTimestampMs) ||
          Number(item.audioTimestampMs) < 0))
    ) {
      throw new Error("Invalid weekly evidence");
    }
    date(item.occurredAt, "evidence.occurredAt");
    return {
      sourceEntryId: item.sourceEntryId,
      week: item.week as "baseline" | "current",
      occurredAt: item.occurredAt as string,
      canonicalTranscript: item.canonicalTranscript,
      ...(item.audioTimestampMs == null
        ? {}
        : { audioTimestampMs: Number(item.audioTimestampMs) }),
    };
  });
  if (
    new Set(evidence.map((item) => item.sourceEntryId)).size !== evidence.length ||
    !evidence.some((item) => item.week === "baseline") ||
    !evidence.some((item) => item.week === "current")
  ) {
    throw new Error("Paired baseline and current evidence is required");
  }
  return {
    userId: value.userId,
    weekStart: value.weekStart as string,
    weekEnd: value.weekEnd as string,
    baselineWeekCount: Number(value.baselineWeekCount),
    localDeltas: value.localDeltas as Record<string, unknown>[],
    evidence,
    activeHypotheses: parseActiveHypotheses(value.activeHypotheses),
    truthAnchors: parseTruthAnchors(value.truthAnchors),
  };
}

export function validateWeeklyIntelligenceResult(
  value: unknown,
  request: WeeklyIntelligenceSynthesisRequest,
): { ok: boolean; errors: string[]; result?: WeeklyIntelligenceSynthesisResult } {
  if (
    !isRecord(value) ||
    value.weekStart !== request.weekStart ||
    value.weekEnd !== request.weekEnd ||
    !Array.isArray(value.deltas)
  ) {
    return { ok: false, errors: ["Weekly result window is invalid"] };
  }
  const sources = new Map(
    request.evidence.map((item) => [
      item.sourceEntryId,
      item.canonicalTranscript,
    ]),
  );
  const weekById = new Map(
    request.evidence.map((item) => [item.sourceEntryId, item.week]),
  );
  const errors: string[] = [];
  value.deltas.forEach((delta, index) => {
    const path = `deltas[${index}]`;
    if (
      !isRecord(delta) ||
      typeof delta.dimension !== "string" ||
      !DIMENSIONS.has(delta.dimension as WeeklyDeltaDimension) ||
      typeof delta.magnitude !== "number" ||
      !Number.isFinite(delta.magnitude) ||
      !Array.isArray(delta.nodeIds) ||
      delta.nodeIds.some((id) => typeof id !== "string")
    ) {
      errors.push(`${path}: invalid delta metadata`);
      return;
    }
    const validation = validateExplainableConclusion(
      delta.conclusion,
      sources,
      `${path}.conclusion`,
    );
    errors.push(...validation.errors);
    const conclusion = validation.conclusion;
    if (validation.ok && conclusion) {
      const representedWeeks = new Set(
        conclusion.evidence.map((item) => weekById.get(item.entryId)),
      );
      if (
        !representedWeeks.has("baseline") ||
        !representedWeeks.has("current")
      ) {
        errors.push(`${path}: paired baseline and current citations required`);
      }
    }
  });
  if (errors.length > 0) return { ok: false, errors };
  return {
    ok: true,
    errors,
    result: value as unknown as WeeklyIntelligenceSynthesisResult,
  };
}

function date(value: unknown, name: string): number {
  if (typeof value !== "string" || Number.isNaN(Date.parse(value))) {
    throw new Error(`Invalid ${name}`);
  }
  return Date.parse(value);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
