import { buildAiFeedbackPromptContext } from "@/lib/ai-feedback/ai-feedback-prompt-context";
import type { HypothesisEvolution } from "@/types/explainability";
import {
  buildTruthAnchorContext,
  type TruthAnchor,
} from "@/lib/ai/truth-anchor-context";

export async function buildHybridAiPromptContext(
  userId: string,
  activeHypotheses: HypothesisEvolution[] = [],
  truthAnchors: TruthAnchor[] = [],
) {
  const negativeFewShotConstraints = await buildAiFeedbackPromptContext(userId);
  const activeHypothesisContext =
    activeHypotheses.length === 0
      ? ""
      : [
          "ACTIVE HYPOTHESES (working theories, not evidence):",
          "Evaluate each theory against this week's new canonical data. State whether it strengthens, weakens, or remains unchanged. Update confidence and include the exact new quote that caused the shift. Preserve theoryId and append one evolutionHistory snapshot. Never cite this context as transcript evidence.",
          ...activeHypotheses.map((hypothesis) => {
            const latest = hypothesis.evolutionHistory.at(-1)!;
            return `- ${hypothesis.theoryId} | ${latest.confidenceScore}% | ${hypothesis.statement} | prior shift: ${latest.deltaReasoning}`;
          }),
        ].join("\n");
  const truthAnchorContext = buildTruthAnchorContext(truthAnchors);
  return {
    negativeFewShotConstraints,
    activeHypothesisContext,
    truthAnchorContext,
  };
}
