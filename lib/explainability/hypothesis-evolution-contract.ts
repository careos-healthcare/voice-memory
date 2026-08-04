import type {
  ConfidenceSnapshot,
  HypothesisEvolution,
  VerifiableCitation,
} from "@/types/explainability";

const SAFE_ID = /^[a-zA-Z0-9_.:-]{1,128}$/;

export function parseActiveHypotheses(value: unknown): HypothesisEvolution[] {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > 20) {
    throw new Error("activeHypotheses must contain at most 20 theories");
  }
  return value.map((item, hypothesisIndex) => {
    if (!isRecord(item) || !SAFE_ID.test(String(item.theoryId ?? ""))) {
      throw new Error(`activeHypotheses[${hypothesisIndex}]: invalid theoryId`);
    }
    const statement =
      typeof item.statement === "string" ? item.statement.trim() : "";
    if (!statement || statement.length > 500) {
      throw new Error(`activeHypotheses[${hypothesisIndex}]: invalid statement`);
    }
    if (
      !Array.isArray(item.evolutionHistory) ||
      item.evolutionHistory.length === 0 ||
      item.evolutionHistory.length > 52
    ) {
      throw new Error(`activeHypotheses[${hypothesisIndex}]: invalid history`);
    }
    let priorDate = 0;
    const evolutionHistory = item.evolutionHistory.map((raw, snapshotIndex) => {
      if (!isRecord(raw)) {
        throw new Error(`activeHypotheses[${hypothesisIndex}]: invalid snapshot`);
      }
      const date = typeof raw.date === "string" ? Date.parse(raw.date) : NaN;
      if (
        Number.isNaN(date) ||
        date < priorDate ||
        !Number.isInteger(raw.confidenceScore) ||
        Number(raw.confidenceScore) < 0 ||
        Number(raw.confidenceScore) > 100 ||
        typeof raw.deltaReasoning !== "string" ||
        raw.deltaReasoning.trim().length < 8
      ) {
        throw new Error(
          `activeHypotheses[${hypothesisIndex}].evolutionHistory[${snapshotIndex}]: invalid snapshot`,
        );
      }
      priorDate = date;
      const triggeringEvidence = parseCitation(raw.triggeringEvidence);
      return {
        date: new Date(date).toISOString(),
        confidenceScore: Number(raw.confidenceScore),
        triggeringEvidence,
        deltaReasoning: raw.deltaReasoning.trim(),
      } satisfies ConfidenceSnapshot;
    });
    if (evolutionHistory.at(-1)!.confidenceScore >= 85) {
      throw new Error(
        `activeHypotheses[${hypothesisIndex}]: confidence must be below 85`,
      );
    }
    return {
      theoryId: String(item.theoryId),
      statement,
      evolutionHistory,
    };
  });
}

function parseCitation(value: unknown): VerifiableCitation {
  if (!isRecord(value)) throw new Error("Invalid triggering evidence");
  const sourceEntryId =
    typeof value.sourceEntryId === "string" ? value.sourceEntryId : "";
  const exactQuote = typeof value.exactQuote === "string" ? value.exactQuote : "";
  const confidenceScore = Number(value.confidenceScore);
  if (
    !sourceEntryId ||
    !exactQuote ||
    !Number.isFinite(confidenceScore) ||
    confidenceScore < 0 ||
    confidenceScore > 1
  ) {
    throw new Error("Invalid triggering evidence");
  }
  const startUtf16 = Number.isInteger(value.startUtf16)
    ? Number(value.startUtf16)
    : 0;
  const endUtf16 = Number.isInteger(value.endUtf16)
    ? Number(value.endUtf16)
    : startUtf16 + exactQuote.length;
  return {
    sourceEntryId,
    exactQuote,
    entryId: sourceEntryId,
    quote: exactQuote,
    confidenceScore,
    startUtf16,
    endUtf16,
    role: "support",
    ...(value.audioTimestampMs == null
      ? {}
      : { audioTimestampMs: Number(value.audioTimestampMs) }),
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
