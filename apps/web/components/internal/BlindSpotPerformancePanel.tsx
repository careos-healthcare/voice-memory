"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EVIDENCE_STRENGTH_LABELS } from "@/lib/blind-spots/blind-spot-copy";
import type { BlindSpotValidationReport } from "@/types/blind-spot";

function pct(rate: number): string {
  return `${Math.round(rate * 100)}%`;
}

interface BlindSpotPerformancePanelProps {
  report: BlindSpotValidationReport;
}

export function BlindSpotPerformancePanel({ report }: BlindSpotPerformancePanelProps) {
  const { metrics } = report;

  return (
    <div className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Total reviews</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-semibold text-white">{metrics.totalReviews}</p>
          </CardContent>
        </Card>
        <Card className="border-violet-500/20 bg-violet-950/20">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-violet-200/80">Self recognition score</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-semibold text-violet-100">
              {metrics.selfRecognitionScore}
            </p>
            <p className="mt-1 text-xs text-zinc-500">
              interesting + surprising + uncomfortably accurate
            </p>
          </CardContent>
        </Card>
        <Card className="border-amber-500/20 bg-amber-950/15">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-amber-200/80">Holy shit score</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-semibold text-amber-100">{metrics.holyShitScore}</p>
            <p className="mt-1 text-xs text-zinc-500">uncomfortably accurate reactions</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Failure score</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-semibold text-zinc-200">{metrics.failureScore}</p>
            <p className="mt-1 text-xs text-zinc-500">obvious + completely wrong</p>
          </CardContent>
        </Card>
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Reaction breakdown</CardTitle>
          <p className="text-xs text-zinc-500">
            Optimize for surprise and self-recognition — not agreement.
          </p>
        </CardHeader>
        <CardContent className="grid gap-2 text-sm text-zinc-400 sm:grid-cols-2">
          <p>Obvious: {pct(metrics.obviousRate)}</p>
          <p>Interesting: {pct(metrics.interestingRate)}</p>
          <p>Surprising: {pct(metrics.surprisingRate)}</p>
          <p>Uncomfortably accurate: {pct(metrics.uncomfortablyAccurateRate)}</p>
          <p>Completely wrong: {pct(metrics.completelyWrongRate)}</p>
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-base text-zinc-200">Top performing blind spots</CardTitle>
            <p className="text-xs text-zinc-500">Highest self-recognition signals</p>
          </CardHeader>
          <CardContent className="space-y-3">
            {report.topPerforming.length === 0 ? (
              <p className="text-sm text-zinc-600">No reactions yet.</p>
            ) : (
              report.topPerforming.map((row) => (
                <div key={row.reviewId} className="rounded-lg border border-white/5 p-3">
                  <p className="text-sm text-zinc-300">{row.headline}</p>
                  <p className="mt-1 text-xs text-zinc-500">
                    Self-recognition {row.selfRecognitionCount} · Holy shit {row.holyShitCount} ·
                    Reviews {row.reviewCount}
                  </p>
                </div>
              ))
            )}
          </CardContent>
        </Card>

        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-base text-zinc-200">Worst performing blind spots</CardTitle>
            <p className="text-xs text-zinc-500">Highest failure signals — “already knew that”</p>
          </CardHeader>
          <CardContent className="space-y-3">
            {report.worstPerforming.length === 0 ? (
              <p className="text-sm text-zinc-600">No reactions yet.</p>
            ) : (
              report.worstPerforming.map((row) => (
                <div key={row.reviewId} className="rounded-lg border border-white/5 p-3">
                  <p className="text-sm text-zinc-300">{row.headline}</p>
                  <p className="mt-1 text-xs text-zinc-500">
                    Failure {row.failureCount} · Self-recognition {row.selfRecognitionCount} ·
                    Reviews {row.reviewCount}
                  </p>
                </div>
              ))
            )}
          </CardContent>
        </Card>
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">
            Evidence strength vs reaction
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {report.evidenceStrengthCorrelation.length === 0 ? (
            <p className="text-sm text-zinc-600">No reactions yet.</p>
          ) : (
            report.evidenceStrengthCorrelation.map((bucket) => (
              <div
                key={bucket.evidenceStrength}
                className="rounded-lg border border-white/5 p-3 text-sm"
              >
                <p className="font-medium text-zinc-300">
                  {EVIDENCE_STRENGTH_LABELS[bucket.evidenceStrength]} ({bucket.total} reviews)
                </p>
                <p className="mt-2 text-xs text-zinc-500">
                  Obvious {bucket.obvious} · Interesting {bucket.interesting} · Surprising{" "}
                  {bucket.surprising} · Uncomfortably accurate {bucket.uncomfortablyAccurate} ·
                  Wrong {bucket.completelyWrong} · Self-recognition {bucket.selfRecognitionCount}
                </p>
              </div>
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
