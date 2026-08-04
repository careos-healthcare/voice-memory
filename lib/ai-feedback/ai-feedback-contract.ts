import type { AiAccuracyFeedback } from "@/types/ai-feedback";

const STATES = new Set(["pending", "correct", "incorrect", "later"]);
const SAFE_ID = /^[a-zA-Z0-9_.:-]{1,128}$/;

export function parseAiAccuracyFeedback(value: unknown): AiAccuracyFeedback {
  if (!isRecord(value)) throw new Error("Feedback must be an object");
  const conclusionId =
    typeof value.conclusionId === "string" ? value.conclusionId.trim() : "";
  const engine = typeof value.engine === "string" ? value.engine.trim() : "";
  const rawState =
    typeof value.feedbackState === "string"
      ? value.feedbackState
      : typeof value.userFeedbackState === "string"
        ? value.userFeedbackState
        : "";
  const state = rawState === "deferred" ? "later" : rawState;
  const timestamp =
    typeof value.feedbackTimestamp === "string"
      ? value.feedbackTimestamp
      : "";
  const note =
    typeof value.correctionNote === "string"
      ? value.correctionNote.trim()
      : typeof value.userCorrectionNote === "string"
        ? value.userCorrectionNote.trim()
      : undefined;
  const nodeIds = Array.isArray(value.nodeIds)
    ? value.nodeIds.map((id) => (typeof id === "string" ? id.trim() : ""))
    : [];
  const edgeIds = Array.isArray(value.edgeIds)
    ? value.edgeIds.map((id) => (typeof id === "string" ? id.trim() : ""))
    : [];
  if (
    !SAFE_ID.test(conclusionId) ||
    !SAFE_ID.test(engine) ||
    !STATES.has(state) ||
    !Number.isInteger(value.confidencePercentage) ||
    Number(value.confidencePercentage) < 0 ||
    Number(value.confidencePercentage) > 100 ||
    Number.isNaN(Date.parse(timestamp)) ||
    nodeIds.length > 64 ||
    edgeIds.length > 64 ||
    nodeIds.some((id) => !SAFE_ID.test(id)) ||
    edgeIds.some((id) => !SAFE_ID.test(id)) ||
    (note != null && (note.length > 500 || /[\u0000-\u0008\u000B\u000C\u000E-\u001F]/.test(note))) ||
    (state !== "incorrect" && note != null)
  ) {
    throw new Error("Invalid AI accuracy feedback");
  }
  return {
    conclusionId,
    engine,
    confidencePercentage: Number(value.confidencePercentage),
    feedbackState: state as AiAccuracyFeedback["feedbackState"],
    feedbackTimestamp: new Date(timestamp).toISOString(),
    ...(note ? { correctionNote: note } : {}),
    nodeIds: [...new Set(nodeIds)].sort(),
    edgeIds: [...new Set(edgeIds)].sort(),
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
