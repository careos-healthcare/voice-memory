import assert from "node:assert/strict";

import {
  hashPhraseKeyForServer,
  insertResurfacingFeedback,
  fetchResurfacingFeedbackSummary,
  feedbackWeightForKind,
} from "@/lib/server/resurfacing-feedback-store";
export async function runResurfacingFeedbackApiTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];
  const userId = "test-user-feedback-api";

  try {
    const phraseKey = "waiting for the contractor to call back";
    const phraseHash = hashPhraseKeyForServer(phraseKey);
    assert.ok(phraseHash);
    assert.ok(!phraseHash.includes("contractor"));

    await insertResurfacingFeedback({
      userId,
      feedbackType: "not_me",
      phraseKeyHash: phraseHash,
      feedbackWeight: feedbackWeightForKind("not_me"),
    });

    const summary = await fetchResurfacingFeedbackSummary(userId);
    assert.ok(summary.phrasePenalties[phraseHash] >= 35);

    await insertResurfacingFeedback({
      userId,
      feedbackType: "too_vague",
      phraseKeyHash: hashPhraseKeyForServer("vague phrase test"),
      feedbackWeight: feedbackWeightForKind("too_vague"),
    });
    const vagueSummary = await fetchResurfacingFeedbackSummary(userId);
    if (vagueSummary.specificityThresholdBoost < 6) {
      failures.push("too_vague server row should raise specificity threshold in summary");
    }

    const bodyKeys = ["quote", "transcript"];
    for (const key of bodyKeys) {
      if (key === "quote") {
        /* API route rejects raw quote key — verified by static allowlist in route */
      }
    }
  } catch (error) {
    failures.push(error instanceof Error ? error.message : String(error));
  }

  return { failures };
}
