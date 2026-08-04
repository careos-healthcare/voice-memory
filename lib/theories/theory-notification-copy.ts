import type { Theory, TheorySource } from "@/types/theory";
import type {
  TheoryNotificationImportance,
  TheoryNotificationRoute,
  TheoryNotificationType,
} from "@/types/theory-notification";

export const FORBIDDEN_NOTIFICATION_COPY =
  /\b(diagnos|disorder|patholog|clinical|therapy|trauma|guaranteed|certainly means you are|you are a narciss|toxic)\b/i;

const SOURCE_HINT: Partial<Record<TheorySource, string>> = {
  pattern: "a recurring pattern",
  blind_spot: "a blind-spot thread",
  prediction: "a prediction you named",
  emerging: "an emerging pattern",
};

function themeHint(theory: Theory): string {
  const fromSource = SOURCE_HINT[theory.source];
  if (fromSource) return fromSource;
  const short = theory.statement.slice(0, 48).replace(/\s+/g, " ").trim();
  return short.length > 12 ? `“${short}…”` : "a working theory";
}

export function sanitizeNotificationCopy(text: string): string {
  if (FORBIDDEN_NOTIFICATION_COPY.test(text)) {
    return "Your archive may suggest a shift in one working theory — open Discover to see details.";
  }
  return text;
}

export function copyForNotification(input: {
  type: TheoryNotificationType;
  theory: Theory;
  evidenceSummary: string;
  confidenceDelta?: number;
}): { title: string; body: string; importance: TheoryNotificationImportance; relatedRoute: TheoryNotificationRoute } {
  const hint = themeHint(input.theory);

  switch (input.type) {
    case "strengthened":
      return {
        title: `A theory about ${hint} strengthened.`,
        body: sanitizeNotificationCopy(
          input.evidenceSummary ||
            `Your archive suggests confidence may have risen${input.confidenceDelta !== undefined ? ` (about ${Math.abs(input.confidenceDelta)} points)` : ""}. Not proof — one thread to revisit.`,
        ),
        importance: Math.abs(input.confidenceDelta ?? 0) >= 10 ? "high" : "medium",
        relatedRoute: "/discover",
      };
    case "weakened":
      return {
        title: `A theory about ${hint} weakened.`,
        body: sanitizeNotificationCopy(
          input.evidenceSummary ||
            `Your archive suggests confidence may have softened${input.confidenceDelta !== undefined ? ` (about ${Math.abs(input.confidenceDelta)} points)` : ""}. Still only a working theory.`,
        ),
        importance: Math.abs(input.confidenceDelta ?? 0) >= 10 ? "high" : "medium",
        relatedRoute: "/discover",
      };
    case "resolved":
      return {
        title: "This theory may no longer fit.",
        body: sanitizeNotificationCopy(
          input.evidenceSummary ||
            `A theory about ${hint} may have moved toward resolved in your current model.`,
        ),
        importance: "high",
        relatedRoute: "/theories",
      };
    case "retired":
      return {
        title: "This theory may no longer fit.",
        body: sanitizeNotificationCopy(
          input.evidenceSummary ||
            `A theory about ${hint} may have been retired — later moments may not support it.`,
        ),
        importance: "high",
        relatedRoute: "/theories",
      };
    case "new_evidence":
      return {
        title: "New evidence appeared for a recurring pattern.",
        body: sanitizeNotificationCopy(
          input.evidenceSummary ||
            `Your archive suggests new supporting words appeared for ${hint}, after a longer gap.`,
        ),
        importance: "low",
        relatedRoute: "/discover",
      };
    case "contradiction":
      return {
        title: "New contradicting evidence appeared.",
        body: sanitizeNotificationCopy(
          input.evidenceSummary ||
            `Your archive suggests pulls that may not line up for ${hint}.`,
        ),
        importance: "high",
        relatedRoute: "/discover",
      };
    case "prediction_outcome":
      return {
        title: "A prediction outcome may have shifted.",
        body: sanitizeNotificationCopy(
          input.evidenceSummary ||
            `Later moments may not match what you expected for ${hint}.`,
        ),
        importance: "medium",
        relatedRoute: "/discover",
      };
    default:
      return {
        title: "Theory update",
        body: "Your archive suggests a change worth a quiet look.",
        importance: "low",
        relatedRoute: "/discover",
      };
  }
}
