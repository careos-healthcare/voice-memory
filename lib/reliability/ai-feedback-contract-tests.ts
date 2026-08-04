import assert from "node:assert/strict";

import { parseAiAccuracyFeedback } from "@/lib/ai-feedback/ai-feedback-contract";
import { buildHybridAiPromptContext } from "@/lib/ai/hybrid-ai-prompt-context";
import { parseTruthAnchors } from "@/lib/ai/truth-anchor-context";
import {
  aiAccuracyMetrics,
  recentAiCorrections,
  renderRecentCorrectionConstraints,
  resetAiFeedbackStoreForTest,
  upsertAiAccuracyFeedback,
} from "@/lib/server/ai-feedback-store";

export async function runAiFeedbackContractTests(): Promise<void> {
  resetAiFeedbackStoreForTest();
  const correct = parseAiAccuracyFeedback({
    conclusionId: "insight-1",
    engine: "weekly_intelligence",
    confidencePercentage: 92,
    feedbackState: "correct",
    feedbackTimestamp: "2026-07-27T00:00:00.000Z",
    nodeIds: ["node-1"],
    edgeIds: [],
  });
  const incorrect = parseAiAccuracyFeedback({
    conclusionId: "insight-2",
    engine: "weekly_intelligence",
    confidencePercentage: 78,
    feedbackState: "incorrect",
    feedbackTimestamp: "2026-07-27T00:01:00.000Z",
    correctionNote: "Deadlines do not cause me to avoid this person.",
    nodeIds: ["node-2", "node-3"],
    edgeIds: ["edge-1"],
  });
  await upsertAiAccuracyFeedback("user-1", correct);
  await upsertAiAccuracyFeedback("user-1", incorrect);

  const metrics = await aiAccuracyMetrics("user-1");
  assert.equal(metrics[0]?.verified, 2);
  assert.equal(metrics[0]?.accuracyPercentage, 50);
  const corrections = await recentAiCorrections("user-1");
  assert.equal(corrections.length, 1);
  assert.match(
    renderRecentCorrectionConstraints(corrections),
    /Do not repeat rejected claims/,
  );
  const promptContext = await buildHybridAiPromptContext("user-1");
  assert.match(
    promptContext.negativeFewShotConstraints,
    /SYSTEM NOTE: The user previously corrected the AI on this topic/,
  );
  assert.match(
    promptContext.negativeFewShotConstraints,
    /Do NOT repeat this assumption/,
  );
  assert.match(
    renderRecentCorrectionConstraints(corrections),
    /Deadlines do not cause/,
  );
  const truthAnchors = parseTruthAnchors([
    {
      kind: "node",
      id: "manual-keto",
      label: "Starting Keto",
      category: "habit",
      origin: "manual",
      confidence: 100,
      note: "A deliberate user-defined commitment",
    },
  ]);
  const anchoredContext = await buildHybridAiPromptContext(
    "user-1",
    [],
    truthAnchors,
  );
  assert.match(anchoredContext.truthAnchorContext, /TRUTH ANCHORS/);
  assert.match(anchoredContext.truthAnchorContext, /absolute ground-truth/);
  assert.match(anchoredContext.truthAnchorContext, /Starting Keto/);
  const externalAnchors = parseTruthAnchors([
    {
      kind: "node",
      id: "health-sleep-2026-07-27",
      label: "Sleep: 7.8h",
      category: "habit",
      origin: "external",
      confidence: 100,
      source: "apple_health",
      observedAt: "2026-07-27T00:00:00.000Z",
    },
    {
      kind: "node",
      id: "spotify-valence-2026-07-27",
      label: "Music valence: 72%",
      category: "emotion",
      origin: "external",
      confidence: 100,
      source: "spotify",
      observedAt: "2026-07-27T23:00:00.000Z",
    },
  ]);
  const externalContext = await buildHybridAiPromptContext(
    "user-1",
    [],
    externalAnchors,
  );
  assert.match(externalContext.truthAnchorContext, /source: apple_health/);
  assert.match(externalContext.truthAnchorContext, /source: spotify/);
  assert.match(externalContext.truthAnchorContext, /100% confidence/);
  assert.match(externalContext.truthAnchorContext, /not transcript evidence/);
  assert.throws(() =>
    parseTruthAnchors([
      {
        kind: "node",
        id: "unlocked",
        label: "Not trusted",
        category: "idea",
        origin: "extracted",
        confidence: 72,
      },
    ]),
  );

  assert.throws(
    () =>
      parseAiAccuracyFeedback({
        ...correct,
        correctionNote: "Unexpected raw note",
      }),
    /Invalid AI accuracy feedback/,
  );
  assert.throws(
    () =>
      parseAiAccuracyFeedback({
        ...incorrect,
        confidencePercentage: 101,
      }),
    /Invalid AI accuracy feedback/,
  );
}
