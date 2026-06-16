"use client";

import { InsightOutcomePrompt } from "@/components/insights/InsightOutcomePrompt";

interface InsightOutcomePromptStackProps {
  className?: string;
}

export function InsightOutcomePromptStack({ className = "" }: InsightOutcomePromptStackProps) {
  return <InsightOutcomePrompt className={className} />;
}
