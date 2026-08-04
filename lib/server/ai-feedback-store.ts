import type {
  AiAccuracyFeedback,
  AiAccuracyMetrics,
} from "@/types/ai-feedback";
import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import { assertAccountDeletionNotPending } from "@/lib/server/privacy/account-deletion-state";

interface StoredAiFeedback extends AiAccuracyFeedback {
  userId: string;
  receivedAt: string;
}

const globalStore = globalThis as typeof globalThis & {
  __archiveMeAiAccuracyFeedback?: Map<string, StoredAiFeedback>;
};

const feedbackStore =
  globalStore.__archiveMeAiAccuracyFeedback ??
  (globalStore.__archiveMeAiAccuracyFeedback = new Map());

export async function upsertAiAccuracyFeedback(
  userId: string,
  feedback: AiAccuracyFeedback,
): Promise<void> {
  await assertAccountDeletionNotPending(userId);
  if (shouldUsePostgresStorage()) {
    await dbQuery(
      `INSERT INTO ai_accuracy_feedback (
        user_id, conclusion_id, engine, confidence_percentage, feedback_state,
        feedback_timestamp, correction_note, node_ids, edge_ids, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, now())
      ON CONFLICT (user_id, conclusion_id) DO UPDATE SET
        engine = EXCLUDED.engine,
        confidence_percentage = EXCLUDED.confidence_percentage,
        feedback_state = EXCLUDED.feedback_state,
        feedback_timestamp = EXCLUDED.feedback_timestamp,
        correction_note = EXCLUDED.correction_note,
        node_ids = EXCLUDED.node_ids,
        edge_ids = EXCLUDED.edge_ids,
        updated_at = now()`,
      [
        userId,
        feedback.conclusionId,
        feedback.engine,
        feedback.confidencePercentage,
        feedback.feedbackState,
        feedback.feedbackTimestamp,
        feedback.correctionNote ?? null,
        JSON.stringify(feedback.nodeIds),
        JSON.stringify(feedback.edgeIds),
      ],
    );
    return;
  }
  feedbackStore.set(`${userId}:${feedback.conclusionId}`, {
    ...feedback,
    userId,
    receivedAt: new Date().toISOString(),
  });
}

export async function deleteAiAccuracyFeedbackForUser(userId: string): Promise<number> {
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery(`DELETE FROM ai_accuracy_feedback WHERE user_id = $1`, [userId]);
    return result.rowCount ?? 0;
  }
  let removed = 0;
  for (const [key, item] of feedbackStore) {
    if (item.userId === userId) {
      feedbackStore.delete(key);
      removed += 1;
    }
  }
  return removed;
}

export function localAiAccuracyFeedbackExists(userId: string): boolean {
  return [...feedbackStore.values()].some((item) => item.userId === userId);
}

export async function recentAiCorrections(
  userId: string,
  limit = 12,
): Promise<AiAccuracyFeedback[]> {
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery<{
      conclusion_id: string;
      engine: string;
      confidence_percentage: number;
      feedback_state: "incorrect";
      feedback_timestamp: Date;
      correction_note: string;
      node_ids: string[];
      edge_ids: string[];
    }>(
      `SELECT conclusion_id, engine, confidence_percentage, feedback_state,
              feedback_timestamp, correction_note, node_ids, edge_ids
       FROM ai_accuracy_feedback
       WHERE user_id = $1 AND feedback_state = 'incorrect'
         AND correction_note IS NOT NULL
       ORDER BY feedback_timestamp DESC
       LIMIT $2`,
      [userId, Math.max(1, Math.min(limit, 50))],
    );
    return result.rows.map((row) => ({
      conclusionId: row.conclusion_id,
      engine: row.engine,
      confidencePercentage: row.confidence_percentage,
      feedbackState: row.feedback_state,
      feedbackTimestamp: row.feedback_timestamp.toISOString(),
      correctionNote: row.correction_note,
      nodeIds: Array.isArray(row.node_ids) ? row.node_ids : [],
      edgeIds: Array.isArray(row.edge_ids) ? row.edge_ids : [],
    }));
  }
  return [...feedbackStore.values()]
    .filter(
      (item) =>
        item.userId === userId &&
        item.feedbackState === "incorrect" &&
        item.correctionNote,
    )
    .sort((a, b) => b.feedbackTimestamp.localeCompare(a.feedbackTimestamp))
    .slice(0, Math.max(1, Math.min(limit, 50)))
    .map((item) => ({
      conclusionId: item.conclusionId,
      engine: item.engine,
      confidencePercentage: item.confidencePercentage,
      feedbackState: item.feedbackState,
      feedbackTimestamp: item.feedbackTimestamp,
      correctionNote: item.correctionNote,
      nodeIds: item.nodeIds,
      edgeIds: item.edgeIds,
    }));
}

export async function aiAccuracyMetrics(
  userId: string,
): Promise<AiAccuracyMetrics[]> {
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery<{
      engine: string;
      correct: number;
      incorrect: number;
      later: number;
    }>(
      `SELECT engine,
        count(*) FILTER (WHERE feedback_state = 'correct')::int AS correct,
        count(*) FILTER (WHERE feedback_state = 'incorrect')::int AS incorrect,
        count(*) FILTER (WHERE feedback_state = 'later')::int AS later
       FROM ai_accuracy_feedback
       WHERE user_id = $1
       GROUP BY engine`,
      [userId],
    );
    return result.rows.map((row) => {
      const verified = row.correct + row.incorrect;
      return {
        engine: row.engine,
        correct: row.correct,
        incorrect: row.incorrect,
        later: row.later,
        verified,
        accuracyPercentage:
          verified === 0 ? 0 : (row.correct * 100) / verified,
      };
    });
  }
  const grouped = new Map<
    string,
    { correct: number; incorrect: number; later: number }
  >();
  for (const item of feedbackStore.values()) {
    if (item.userId !== userId) continue;
    const counts = grouped.get(item.engine) ?? {
      correct: 0,
      incorrect: 0,
      later: 0,
    };
    if (item.feedbackState === "correct") counts.correct++;
    if (item.feedbackState === "incorrect") counts.incorrect++;
    if (item.feedbackState === "later") counts.later++;
    grouped.set(item.engine, counts);
  }
  return [...grouped.entries()].map(([engine, counts]) => {
    const verified = counts.correct + counts.incorrect;
    return {
      engine,
      ...counts,
      verified,
      accuracyPercentage:
        verified === 0 ? 0 : (counts.correct * 100) / verified,
    };
  });
}

export function renderRecentCorrectionConstraints(
  corrections: AiAccuracyFeedback[],
): string {
  if (corrections.length === 0) return "";
  return [
    "USER-VERIFIED CORRECTION CONSTRAINTS:",
    "Treat these as negative examples, never as evidence. Do not repeat rejected claims.",
    ...corrections.map(
      (item) =>
        `SYSTEM NOTE: The user previously corrected the AI on this topic: ${item.correctionNote} Do NOT repeat this assumption. [${item.engine}/${item.conclusionId}]`,
    ),
  ].join("\n");
}

export function resetAiFeedbackStoreForTest(): void {
  feedbackStore.clear();
}
