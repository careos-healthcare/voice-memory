"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { BlindSpotQualityReport } from "@/types/blind-spot-quality";

interface BlindSpotQualityPanelProps {
  report: BlindSpotQualityReport;
}

function outcomeTags(outcomes: BlindSpotQualityReport["topPerformers"][0]["outcomes"]): string {
  const tags: string[] = [];
  if (outcomes.surprising) tags.push("surprising");
  if (outcomes.uncomfortablyAccurate) tags.push("uncomfortably accurate");
  if (outcomes.breakthrough) tags.push("breakthrough");
  if (outcomes.actedDifferently) tags.push("acted differently");
  if (outcomes.problemImproved) tags.push("problem improved");
  return tags.length > 0 ? tags.join(" · ") : "no change signals yet";
}

export function BlindSpotQualityPanel({ report }: BlindSpotQualityPanelProps) {
  return (
    <section className="space-y-6 border-t border-white/5 pt-10">
      <div>
        <h2 className="text-lg font-medium text-zinc-200">
          What creates the strongest blind spots?
        </h2>
        <p className="mt-1 max-w-2xl text-sm text-zinc-500">
          Which generated blind spots led to surprising reactions, breakthroughs, and behavior
          change — not opens or views. Local records on this device only.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Generated reviews</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.totalRecords}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">With change signals</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.recordsWithOutcomes}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Ranked by quality score</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-zinc-400">
              Surprising · uncomfortably accurate · breakthrough · behavior change
            </p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card className="border-emerald-500/15 bg-emerald-950/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-emerald-100">Top performers</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            {report.topPerformers.length === 0 ? (
              <p className="text-zinc-600">No quality records yet.</p>
            ) : (
              report.topPerformers.map((row) => (
                <div key={`${row.reviewId}-${row.generatedAt}`} className="border-t border-white/5 pt-3 first:border-0 first:pt-0">
                  <p className="font-medium text-zinc-200">{row.headline}</p>
                  <p className="mt-1 text-xs text-zinc-500">
                    Quality {row.blindSpotQualityScore} · scorecard {row.scorecardScore} ·{" "}
                    {row.evidenceStrength}
                  </p>
                  <p className="mt-1 text-xs text-emerald-200/80">{outcomeTags(row.outcomes)}</p>
                </div>
              ))
            )}
          </CardContent>
        </Card>

        <Card className="border-zinc-700/40 bg-zinc-900/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-300">Weakest performers</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            {report.bottomPerformers.length === 0 ? (
              <p className="text-zinc-600">No quality records yet.</p>
            ) : (
              report.bottomPerformers.map((row) => (
                <div key={`${row.reviewId}-bottom-${row.generatedAt}`} className="border-t border-white/5 pt-3 first:border-0 first:pt-0">
                  <p className="font-medium text-zinc-300">{row.headline}</p>
                  <p className="mt-1 text-xs text-zinc-500">
                    Quality {row.blindSpotQualityScore} · scorecard {row.scorecardScore}
                  </p>
                  <p className="mt-1 text-xs text-zinc-600">{outcomeTags(row.outcomes)}</p>
                </div>
              ))
            )}
          </CardContent>
        </Card>
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-zinc-300">Ingredient frequencies</CardTitle>
        </CardHeader>
        <CardContent className="grid gap-2 sm:grid-cols-2 text-sm text-zinc-400">
          {report.ingredientFrequencies.map((row) => (
            <p key={row.key}>
              {row.label}: {row.count} ({row.frequency ?? "—"}%)
            </p>
          ))}
        </CardContent>
      </Card>

      <Card className="border-violet-500/15 bg-violet-950/10">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-violet-100">Success multipliers</CardTitle>
          <p className="text-xs text-zinc-500">Top vs bottom cohorts by quality score</p>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-300">
          {report.successMultipliers.map((row) => (
            <p key={row.key}>{row.line}</p>
          ))}
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
