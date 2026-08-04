import {
  recentAiCorrections,
  renderRecentCorrectionConstraints,
} from "@/lib/server/ai-feedback-store";

/**
 * Shared Hybrid AI context builder for all cloud synthesis routes.
 *
 * Corrections are instructions, never evidence, and therefore must not be
 * copied into citations or treated as transcript text.
 */
export async function buildAiFeedbackPromptContext(
  userId: string,
): Promise<string> {
  return renderRecentCorrectionConstraints(await recentAiCorrections(userId));
}
