"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { InsightOutcomeReport } from "@/types/insight-outcome";

interface InsightOutcomePanelProps {
  report: InsightOutcomeReport;
}

function rateLabel(value: number | null): string {
  return value === null ? "—" : `${value}%`;
}

export function InsightOutcomePanel({ report }: InsightOutcomePanelProps) {
  return (
    <section className="space-y-6 border-t border-white/5 pt-10">
      <div>
        <h2 className="text-lg font-medium text-zinc-200">Behavior Change Outcomes</h2>
        <p className="mt-1 max-w-2xl text-sm text-zinc-500">
          Do blind spots and theories lead to real-world change? Local outcome prompts only — no
          new analysis, just tracking.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Overall improvement</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {rateLabel(report.overallOutcomeRate)}
            </p>
            <p className="mt-1 text-xs text-zinc-600">{report.totalResponses} responses</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Acted differently</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {rateLabel(report.actedDifferentlyRate)}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Problem improved</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {rateLabel(report.problemImprovedRate)}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Caught earlier</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {rateLabel(report.caughtEarlierRate)}
            </p>
          </CardContent>
        </Card>
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-zinc-300">Outcome funnel</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-zinc-400">
          {report.funnel.map((step) => (
            <p key={step.outcome}>
              {step.label}: {step.count} ({rateLabel(step.share)})
            </p>
          ))}
        </CardContent>
      </Card>

      <Card className="border-teal-500/20 bg-teal-950/10">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-teal-100">Ingredient effectiveness</CardTitle>
          <p className="text-xs text-zinc-500">Improvement rate by scorecard ingredient</p>
        </CardHeader>
        <CardContent>
          <div className="grid gap-2 text-sm sm:grid-cols-2">
            <p className="text-xs uppercase tracking-wider text-zinc-600">Ingredient</p>
            <p className="text-xs uppercase tracking-wider text-zinc-600 text-right sm:text-left">
              Improvement rate
            </p>
            {report.byIngredient.map((row) => (
              <div key={row.ingredient} className="contents">
                <p className="text-zinc-300">{row.label}</p>
                <p className="text-zinc-400 text-right sm:text-left">
                  {rateLabel(row.improvementRate)} ({row.improvementCount}/{row.appearances})
                </p>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="border-violet-500/20 bg-violet-950/15">
          <CardHeader className="pb-2">
            <CardTitle className="text-base text-violet-100">{report.winningInsightTitle}</CardTitle>
            <p className="text-xs text-zinc-500">Top profiles — acted differently / situation improved</p>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-400">
            {report.topProfiles.length === 0 ? (
              <p className="text-zinc-600">No outcome data yet.</p>
            ) : (
              report.topProfiles.map((row) => (
                <p key={row.profileKey}>
                  <span className="text-zinc-200">{row.label}</span> — success{" "}
                  {rateLabel(row.successRate)} ({row.successCount}/{row.appearances})
                </p>
              ))
            )}
          </CardContent>
        </Card>

        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-300">Weakest profiles</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-500">
            {report.weakestProfiles.length === 0 ? (
              <p className="text-zinc-600">No outcome data yet.</p>
            ) : (
              report.weakestProfiles.map((row) => (
                <p key={row.profileKey}>
                  {row.label} — {rateLabel(row.successRate)} ({row.appearances} appearances)
                </p>
              ))
            )}
          </CardContent>
        </Card>
      </div>

      <ul className="space-y-1 text-xs text-zinc-600">
        {report.lines.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>
    </section>
  );
}
