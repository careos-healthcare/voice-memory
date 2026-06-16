"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { InsightIngredientOptimizerReport } from "@/types/insight-ingredient-optimizer";

interface InsightIngredientOptimizerPanelProps {
  report: InsightIngredientOptimizerReport;
}

function rateLabel(value: number | null): string {
  return value === null ? "—" : `${value}%`;
}

export function InsightIngredientOptimizerPanel({
  report,
}: InsightIngredientOptimizerPanelProps) {
  return (
    <section className="space-y-6 border-t border-white/5 pt-10">
      <div>
        <h2 className="text-lg font-medium text-zinc-200">Insight Ingredient Optimizer</h2>
        <p className="mt-1 max-w-2xl text-sm text-zinc-500">
          Ranking concentration from quality data — not a new detector. A-tier blind spots contain
          3+ high-value ingredients. D-tier blind spots contain none.
        </p>
        {report.lowSampleWarning ? (
          <p className="mt-2 text-sm text-amber-200/90">
            Sample size is low on this device — treat multipliers as directional only.
          </p>
        ) : null}
      </div>

      <div className="grid gap-4 sm:grid-cols-4">
        <Card className="border-emerald-500/15 bg-emerald-950/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-emerald-100">A-tier</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.tierCounts.a_tier}</p>
            <p className="mt-1 text-xs text-zinc-500">3–4 ingredients</p>
          </CardContent>
        </Card>
        <Card className="border-violet-500/15 bg-violet-950/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-violet-100">B-tier</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.tierCounts.b_tier}</p>
            <p className="mt-1 text-xs text-zinc-500">2 ingredients</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">C-tier</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.tierCounts.c_tier}</p>
            <p className="mt-1 text-xs text-zinc-500">1 ingredient</p>
          </CardContent>
        </Card>
        <Card className="border-zinc-700/40 bg-zinc-900/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">D-tier</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.tierCounts.d_tier}</p>
            <p className="mt-1 text-xs text-zinc-500">0 ingredients</p>
          </CardContent>
        </Card>
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-zinc-300">Success rate by tier</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.tierOutcomeRates.map((row) => (
            <p key={row.tier}>
              {row.tierLabel}: n={row.count} · overall {rateLabel(row.overallSuccessRate)} ·
              breakthrough {rateLabel(row.breakthroughRate)} · acted differently{" "}
              {rateLabel(row.actedDifferentlyRate)}
            </p>
          ))}
        </CardContent>
      </Card>

      <Card className="border-violet-500/15 bg-violet-950/10">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-violet-100">Ingredient success multipliers</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-300">
          {report.successMultipliers.map((row) => (
            <p key={row.label}>{row.line}</p>
          ))}
        </CardContent>
      </Card>

      <Card className="border-amber-500/15 bg-amber-950/10">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-amber-100">Recommendation</CardTitle>
        </CardHeader>
        <CardContent className="text-sm text-zinc-300">
          <p className="font-medium text-amber-100/90">{report.recommendation}</p>
          <p className="mt-2 text-zinc-400">{report.recommendationLine}</p>
        </CardContent>
      </Card>

      <ul className="space-y-1 text-xs text-zinc-600">
        {report.lines.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>
    </section>
  );
}
