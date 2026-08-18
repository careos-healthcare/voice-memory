"use client";

import { SCORECARD_HELPER_COPY } from "@/lib/insights/insight-scorecard";
import type { InsightScorecard } from "@/types/insight-scorecard";
import { cn } from "@/lib/utils";

const SCORE_LABEL_COPY: Record<InsightScorecard["scoreLabel"], string> = {
  low: "Lower likelihood",
  medium: "Moderate likelihood",
  high: "Higher likelihood",
  very_high: "Stronger likelihood",
};

interface InsightScorecardPanelProps {
  scorecard: InsightScorecard;
  className?: string;
}

export function InsightScorecardPanel({ scorecard, className }: InsightScorecardPanelProps) {
  return (
    <div
      className={cn(
        "rounded-xl border border-white/[0.06] bg-white/[0.02] px-3 py-3",
        className,
      )}
    >
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <p className="text-xs font-medium text-zinc-400">Recognition likelihood</p>
        <p className="text-xs text-violet-300/90">{SCORE_LABEL_COPY[scorecard.scoreLabel]}</p>
      </div>

      <ul className="mt-2 space-y-1">
        {scorecard.ingredients.map((row) => (
          <li
            key={row.key}
            className={cn(
              "text-xs leading-relaxed",
              row.present ? "text-zinc-400" : "text-zinc-700",
            )}
          >
            {row.present ? "✓" : "○"} {row.label}
          </li>
        ))}
      </ul>

      <p className="mt-2 text-[11px] leading-relaxed text-zinc-600">{SCORECARD_HELPER_COPY}</p>
    </div>
  );
}
