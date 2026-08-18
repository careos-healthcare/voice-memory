import type { InsightOutcomeResponse } from "@/types/insight-outcome";

export const INSIGHT_OUTCOME_COPY = {
  question: "What happened after this insight?",
  helper: "Optional — helps ArchiveMe learn which insights lead to real-world change. Not therapy or advice.",
  dismiss: "Skip for now",
} as const;

export const INSIGHT_OUTCOME_LABELS: Record<InsightOutcomeResponse, string> = {
  no_change: "Nothing changed",
  noticed_pattern: "I noticed it again",
  caught_it_earlier: "I caught it earlier",
  acted_differently: "I acted differently",
  problem_improved: "The situation improved",
  theory_stopped_fitting: "This theory no longer fits",
};

export const INGREDIENT_REPORT_LABELS = {
  contradiction: "Contradiction",
  cost_evidence: "Cost Evidence",
  cross_life_area: "Cross Life Area",
  failed_prediction: "Failed Prediction",
  long_span: "Long Span",
} as const;
