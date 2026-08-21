"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { SelfRecognitionIngredientsReport } from "@/types/self-recognition-ingredients";

interface SelfRecognitionIngredientsPanelProps {
  report: SelfRecognitionIngredientsReport;
}

const SURFACE_LABELS: Record<SelfRecognitionIngredientsReport["bySurface"][0]["surface"], string> = {
  blind_spot: "Blind spot",
  theory: "Theory",
  emerging: "Emerging pattern",
  prediction: "Prediction",
};

export function SelfRecognitionIngredientsPanel({
  report,
}: SelfRecognitionIngredientsPanelProps) {
  return (
    <section className="space-y-4 border-t border-white/5 pt-10">
      <div>
        <h2 className="text-lg font-medium text-zinc-200">
          Strongest vs weakest insight analysis
        </h2>
        <p className="mt-1 max-w-2xl text-sm leading-relaxed text-zinc-500">
          What tends to accompany Surprising and Uncomfortably Accurate reactions vs obvious or
          not-true — across blind spot, theory, emerging, and prediction feedback.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <Card className="border-emerald-500/20 bg-emerald-950/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-emerald-100">Strong reactions</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.strongReactionCount}</p>
          </CardContent>
        </Card>
        <Card className="border-amber-500/20 bg-amber-950/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-amber-100">Weak reactions</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.weakReactionCount}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Neutral / other</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.neutralReactionCount}</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="border-violet-500/20 bg-violet-950/15">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-violet-100">Common ingredients — strongest</CardTitle>
            <p className="text-xs text-zinc-500">Surprising · uncomfortably accurate · theory surprising</p>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-400">
            {report.commonStrongIngredients.map((line) => (
              <p key={line}>{line}</p>
            ))}
          </CardContent>
        </Card>
        <Card className="border-amber-500/20 bg-amber-950/15">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-amber-100">Common ingredients — weakest</CardTitle>
            <p className="text-xs text-zinc-500">Obvious · completely wrong · not true · too obvious</p>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-400">
            {report.commonWeakIngredients.map((line) => (
              <p key={line}>{line}</p>
            ))}
          </CardContent>
        </Card>
      </div>

      <Card className="border-emerald-500/20 bg-emerald-950/10">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-emerald-100">
            Why this felt accurate (ingredient correlation)
          </CardTitle>
          <p className="text-xs text-zinc-500">
            Compares time span, contradictions, prediction failures, life areas, cost evidence,
            root belief, and specificity against reaction tiers.
          </p>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.accuracyCorrelationLines.map((line) => (
            <p key={line}>{line}</p>
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Ingredient comparison (avg)</CardTitle>
        </CardHeader>
        <CardContent className="overflow-x-auto">
          <table className="w-full text-left text-sm text-zinc-400">
            <thead>
              <tr className="border-b border-white/10 text-xs uppercase tracking-wide text-zinc-500">
                <th className="py-2 pr-4">Metric</th>
                <th className="py-2 pr-4">Strong</th>
                <th className="py-2 pr-4">Weak</th>
                <th className="py-2">Delta</th>
              </tr>
            </thead>
            <tbody>
              {report.ingredientComparisons.map((row) => (
                <tr key={row.key} className="border-b border-white/5">
                  <td className="py-2 pr-4 text-zinc-300">{row.label}</td>
                  <td className="py-2 pr-4">{row.strongAverage ?? "—"}</td>
                  <td className="py-2 pr-4">{row.weakAverage ?? "—"}</td>
                  <td className="py-2">
                    {row.delta === null ? "—" : row.delta > 0 ? `+${row.delta}` : row.delta}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-300">Strongest insights</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm text-zinc-400">
            {report.strongestInsights.length === 0 ? (
              <p className="text-zinc-600">No strong reactions yet.</p>
            ) : (
              report.strongestInsights.map((row) => (
                <div key={row.id} className="rounded-lg border border-white/5 px-3 py-2">
                  <p className="text-zinc-200">{row.headline}</p>
                  <p className="mt-1 text-xs text-zinc-500">
                    {SURFACE_LABELS[row.surface]} · {row.reaction} · wow {row.wowScore}
                  </p>
                  <p className="mt-1 text-xs text-zinc-600">
                    Quotes {row.ingredients.evidenceQuoteCount} · span {row.ingredients.timeSpanDays}d
                    · areas {row.ingredients.lifeAreaCount} · contradictions{" "}
                    {row.ingredients.contradictionCount} · pred fail{" "}
                    {row.ingredients.predictionFailureCount} · cost{" "}
                    {row.ingredients.costEvidenceCount} · root{" "}
                    {row.ingredients.rootBeliefPresent} · specificity{" "}
                    {row.ingredients.specificityScore} · confidence{" "}
                    {row.ingredients.confidenceScore}
                  </p>
                </div>
              ))
            )}
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-300">Weakest insights</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm text-zinc-400">
            {report.weakestInsights.length === 0 ? (
              <p className="text-zinc-600">No weak reactions yet.</p>
            ) : (
              report.weakestInsights.map((row) => (
                <div key={row.id} className="rounded-lg border border-white/5 px-3 py-2">
                  <p className="text-zinc-200">{row.headline}</p>
                  <p className="mt-1 text-xs text-zinc-500">
                    {SURFACE_LABELS[row.surface]} · {row.reaction} · wow {row.wowScore}
                  </p>
                  <p className="mt-1 text-xs text-zinc-600">
                    Quotes {row.ingredients.evidenceQuoteCount} · span {row.ingredients.timeSpanDays}d
                    · areas {row.ingredients.lifeAreaCount} · contradictions{" "}
                    {row.ingredients.contradictionCount} · cost{" "}
                    {row.ingredients.costEvidenceCount} · confidence{" "}
                    {row.ingredients.confidenceScore}
                  </p>
                </div>
              ))
            )}
          </CardContent>
        </Card>
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-zinc-300">By surface</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-wrap gap-4 text-sm text-zinc-400">
          {report.bySurface.map((row) => (
            <p key={row.surface}>
              {SURFACE_LABELS[row.surface]}: {row.strongCount} strong · {row.weakCount} weak
            </p>
          ))}
        </CardContent>
      </Card>
    </section>
  );
}
