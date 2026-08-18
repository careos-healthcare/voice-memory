import "server-only";

import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";

export const EVIDENCE_INSIGHT_CORRECTION_REASONS = [
  "outOfContext",
  "changedMyMind",
  "notTrue",
  "wrongPattern",
  "wrongWording",
  "tooPersonal",
  "doesNotBelong",
  "notUseful",
] as const;

export type EvidenceInsightCorrectionReason =
  (typeof EVIDENCE_INSIGHT_CORRECTION_REASONS)[number];

export function isEvidenceInsightCorrectionReason(
  value: string,
): value is EvidenceInsightCorrectionReason {
  return (EVIDENCE_INSIGHT_CORRECTION_REASONS as readonly string[]).includes(value);
}

export interface InsertInsightCorrectionInput {
  userId: string;
  insightId: string;
  reason: EvidenceInsightCorrectionReason;
}

function assertPostgresAvailable(): void {
  if (!shouldUsePostgresStorage()) {
    throw new Error("DATABASE_URL is required to store insight corrections.");
  }
}

export async function insertInsightCorrection(
  input: InsertInsightCorrectionInput,
): Promise<void> {
  assertPostgresAvailable();

  const userId = input.userId.trim();
  const insightId = input.insightId.trim();

  if (!userId || !insightId) {
    throw new Error("userId and insightId are required for insight corrections.");
  }

  await dbQuery(
    `INSERT INTO insight_corrections (user_id, insight_id, reason)
     VALUES ($1, $2, $3)`,
    [userId, insightId, input.reason],
  );
}

export async function listSuppressedInsightIds(userId: string): Promise<Set<string>> {
  assertPostgresAvailable();

  const normalizedUserId = userId.trim();
  if (!normalizedUserId) {
    return new Set();
  }

  const result = await dbQuery<{ insight_id: string }>(
    `SELECT DISTINCT insight_id
     FROM insight_corrections
     WHERE user_id = $1`,
    [normalizedUserId],
  );

  return new Set(result.rows.map((row) => row.insight_id));
}
