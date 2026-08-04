import type { ResurfacingFeedbackKind } from "@/lib/resurfacing/resurfacing-feedback";
import { hashResurfacingKey, evidenceClusterHash } from "@/lib/resurfacing/resurfacing-privacy-hash";
import {
  FEEDBACK_WEIGHT_BY_KIND,
  emptyFeedbackSummary,
  type ResurfacingFeedbackSummary,
} from "@/lib/resurfacing/resurfacing-feedback-summary";
import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";

export interface ResurfacingFeedbackRecordInput {
  userId: string;
  feedbackType: ResurfacingFeedbackKind;
  phraseKeyHash: string;
  feedbackWeight: number;
  evidenceClusterHash?: string;
  topicHash?: string;
  personHash?: string;
  metadata?: Record<string, string | number | boolean | null>;
}

export function hashPhraseKeyForServer(phraseKey: string): string {
  return hashResurfacingKey(phraseKey);
}

export function hashTopicKeyForServer(topicKey: string): string {
  return hashResurfacingKey(`topic:${topicKey}`);
}

export function hashPersonKeyForServer(personKey: string): string {
  return hashResurfacingKey(`person:${personKey}`);
}

export { evidenceClusterHash };

const memoryRows = globalThis as typeof globalThis & {
  __vmResurfacingFeedback?: ResurfacingFeedbackRecordInput[];
};

export async function insertResurfacingFeedback(
  input: ResurfacingFeedbackRecordInput,
): Promise<void> {
  if (shouldUsePostgresStorage()) {
    await dbQuery(
      `INSERT INTO resurfacing_feedback (
        user_id, phrase_key_hash, feedback_type, feedback_weight,
        evidence_cluster_hash, topic_hash, person_hash, metadata
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        input.userId,
        input.phraseKeyHash,
        input.feedbackType,
        input.feedbackWeight,
        input.evidenceClusterHash ?? null,
        input.topicHash ?? null,
        input.personHash ?? null,
        JSON.stringify(input.metadata ?? {}),
      ],
    );
    return;
  }
  if (!memoryRows.__vmResurfacingFeedback) memoryRows.__vmResurfacingFeedback = [];
  memoryRows.__vmResurfacingFeedback.push(input);
}

export async function fetchResurfacingFeedbackSummary(
  userId: string,
): Promise<ResurfacingFeedbackSummary> {
  const summary = emptyFeedbackSummary();
  summary.source = "merged";

  if (shouldUsePostgresStorage()) {
    const result = await dbQuery<{
      phrase_key_hash: string;
      feedback_type: string;
      feedback_weight: number;
      topic_hash: string | null;
      person_hash: string | null;
      evidence_cluster_hash: string | null;
    }>(
      `SELECT phrase_key_hash, feedback_type, feedback_weight, topic_hash, person_hash, evidence_cluster_hash
       FROM resurfacing_feedback
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 500`,
      [userId],
    );

    for (const row of result.rows) {
      applyRowToSummary(summary, row);
    }
    return summary;
  }

  const rows = (memoryRows.__vmResurfacingFeedback ?? []).filter((r) => r.userId === userId);
  for (const row of rows) {
    applyRowToSummary(summary, {
      phrase_key_hash: row.phraseKeyHash,
      feedback_type: row.feedbackType,
      feedback_weight: row.feedbackWeight,
      topic_hash: row.topicHash ?? null,
      person_hash: row.personHash ?? null,
      evidence_cluster_hash: row.evidenceClusterHash ?? null,
    });
  }
  return summary;
}

function applyRowToSummary(
  summary: ResurfacingFeedbackSummary,
  row: {
    phrase_key_hash: string;
    feedback_type: string;
    feedback_weight: number;
    topic_hash: string | null;
    person_hash: string | null;
    evidence_cluster_hash: string | null;
  },
): void {
  const kind = row.feedback_type as ResurfacingFeedbackKind;
  const weight = row.feedback_weight;

  if (row.phrase_key_hash) {
    if (kind === "that_fits") {
      summary.acceptanceBoosts[row.phrase_key_hash] = Math.max(
        summary.acceptanceBoosts[row.phrase_key_hash] ?? 0,
        Math.abs(weight),
      );
    } else {
      summary.phrasePenalties[row.phrase_key_hash] = Math.max(
        summary.phrasePenalties[row.phrase_key_hash] ?? 0,
        weight,
      );
    }
    if (kind === "not_me") summary.clusterRetired[row.phrase_key_hash] = true;
    if (kind === "not_me" || kind === "already_know" || kind === "show_less") {
      const days = kind === "not_me" ? 30 : kind === "already_know" ? 21 : 14;
      const until = new Date();
      until.setDate(until.getDate() + days);
      summary.clusterCooldownUntil[row.phrase_key_hash] = until.toISOString();
    }
  }

  if (row.topic_hash && kind === "wrong_topic") {
    summary.topicPenalties[row.topic_hash] = Math.max(
      summary.topicPenalties[row.topic_hash] ?? 0,
      weight,
    );
  }
  if (row.person_hash && kind === "wrong_person") {
    summary.personPenalties[row.person_hash] = Math.max(
      summary.personPenalties[row.person_hash] ?? 0,
      weight,
    );
  }
  if (kind === "too_vague") {
    summary.specificityThresholdBoost += 6;
  }
  if (kind === "too_intense") summary.intensityCautious = true;
}

export function feedbackWeightForKind(kind: ResurfacingFeedbackKind): number {
  const w = FEEDBACK_WEIGHT_BY_KIND[kind];
  return kind === "that_fits" ? Math.abs(w) : w;
}

export async function deleteResurfacingFeedbackForUser(userId: string): Promise<void> {
  if (shouldUsePostgresStorage()) {
    await dbQuery(`DELETE FROM resurfacing_feedback WHERE user_id = $1`, [userId]);
    return;
  }
  if (memoryRows.__vmResurfacingFeedback) {
    memoryRows.__vmResurfacingFeedback = memoryRows.__vmResurfacingFeedback.filter(
      (r) => r.userId !== userId,
    );
  }
}

export function localResurfacingFeedbackExists(userId: string): boolean {
  return (memoryRows.__vmResurfacingFeedback ?? []).some((row) => row.userId === userId);
}
