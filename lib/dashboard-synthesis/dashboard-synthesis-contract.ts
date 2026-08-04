import { validateExplainableConclusion } from "@/lib/explainability/validate-explainable-conclusion";
import { parseActiveHypotheses } from "@/lib/explainability/hypothesis-evolution-contract";
import { parseTruthAnchors } from "@/lib/ai/truth-anchor-context";
import type {
  DashboardSynthesisRequest,
  DashboardSynthesisResult,
  DashboardTimeHorizon,
} from "@/types/dashboard-synthesis";

const HORIZONS = new Set<DashboardTimeHorizon>([
  "today",
  "this_month",
  "this_year",
]);

export function parseDashboardSynthesisRequest(
  value: unknown,
): DashboardSynthesisRequest {
  if (!isRecord(value)) throw new Error("Request must be an object");
  if (
    typeof value.userId !== "string" ||
    !value.userId ||
    typeof value.horizon !== "string" ||
    !HORIZONS.has(value.horizon as DashboardTimeHorizon) ||
    !isRecord(value.localMetrics) ||
    !Array.isArray(value.evidence)
  ) {
    throw new Error("Invalid dashboard synthesis request");
  }
  const evidence = value.evidence.map((item) => {
    if (
      !isRecord(item) ||
      typeof item.sourceEntryId !== "string" ||
      !item.sourceEntryId ||
      typeof item.occurredAt !== "string" ||
      Number.isNaN(Date.parse(item.occurredAt)) ||
      typeof item.canonicalTranscript !== "string" ||
      !item.canonicalTranscript ||
      (item.audioTimestampMs != null &&
        (!Number.isInteger(item.audioTimestampMs) ||
          Number(item.audioTimestampMs) < 0))
    ) {
      throw new Error("Invalid dashboard evidence");
    }
    return {
      sourceEntryId: item.sourceEntryId,
      occurredAt: item.occurredAt,
      canonicalTranscript: item.canonicalTranscript,
      ...(item.audioTimestampMs == null
        ? {}
        : { audioTimestampMs: Number(item.audioTimestampMs) }),
    };
  });
  if (new Set(evidence.map((item) => item.sourceEntryId)).size !== evidence.length) {
    throw new Error("Dashboard evidence IDs must be unique");
  }
  return {
    userId: value.userId,
    horizon: value.horizon as DashboardTimeHorizon,
    localMetrics: value.localMetrics,
    evidence,
    activeHypotheses: parseActiveHypotheses(value.activeHypotheses),
    truthAnchors: parseTruthAnchors(value.truthAnchors),
  };
}

export function validateDashboardSynthesisResult(
  value: unknown,
  request: DashboardSynthesisRequest,
): { ok: boolean; errors: string[]; result?: DashboardSynthesisResult } {
  if (!isRecord(value)) return { ok: false, errors: ["result must be an object"] };
  if (value.horizon !== request.horizon) {
    return { ok: false, errors: ["horizon mismatch"] };
  }
  const sources = new Map(
    request.evidence.map((item) => [
      item.sourceEntryId,
      item.canonicalTranscript,
    ]),
  );
  const errors: string[] = [];
  const identity = value.identity;
  if (identity != null) {
    errors.push(
      ...validateExplainableConclusion(identity, sources, "identity").errors,
    );
  }
  for (const [name, conclusions] of [
    ["goals", value.goals],
    ["predictions", value.predictions],
  ] as const) {
    if (!Array.isArray(conclusions)) {
      errors.push(`${name}: must be an array`);
      continue;
    }
    conclusions.forEach((conclusion, index) => {
      errors.push(
        ...validateExplainableConclusion(
          conclusion,
          sources,
          `${name}[${index}]`,
        ).errors,
      );
    });
  }
  if (errors.length > 0) return { ok: false, errors };
  return { ok: true, errors, result: value as unknown as DashboardSynthesisResult };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
