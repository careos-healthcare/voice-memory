"use client";

import { InsightOutcomePrompt } from "@/archived-components/_archived/insights/InsightOutcomePrompt";

interface InsightOutcomePromptStackProps {
  className?: string;
}

export function InsightOutcomePromptStack({ className = "" }: InsightOutcomePromptStackProps) {
  return <InsightOutcomePrompt className={className} />;
}
