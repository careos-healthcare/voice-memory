"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { ArchiveValueMetricsReport } from "@/types/archive-value";

interface ArchiveValueProgressPanelProps {
  report: ArchiveValueMetricsReport;
}

function rateLabel(value: number | null): string {
  return value === null ? "—" : `${value}%`;
}

export function ArchiveValueProgressPanel({ report }: ArchiveValueProgressPanelProps) {
  return (
    <section className="space-y-6 border-t border-white/5 pt-10">
      <div>
        <h2 className="text-lg font-medium text-zinc-200">Archive value progression</h2>
        <p className="mt-1 max-w-2xl text-sm text-zinc-500">
          Whether reflections visibly strengthen the archive — local events on this device only.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Banner shown</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.bannerShownCount}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Banner CTA clicks</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.bannerCtaClickedCount}</p>
            <p className="mt-1 text-xs text-zinc-600">
              Click rate:{" "}
              {rateLabel(
                report.bannerShownCount > 0
                  ? Math.round(
                      (report.bannerCtaClickedCount / report.bannerShownCount) * 1000,
                    ) / 10
                  : null,
              )}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Ladder seen</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.ladderSeenCount}</p>
          </CardContent>
        </Card>
      </div>

      <Card className="border-emerald-500/15 bg-emerald-950/10">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-emerald-100">Stage reaches</CardTitle>
        </CardHeader>
        <CardContent className="grid gap-2 text-sm text-zinc-400 sm:grid-cols-2">
          <p>One data point: {report.stageCounts.one_data_point}</p>
          <p>Possible repeat: {report.stageCounts.possible_repeat}</p>
          <p>Pattern forming: {report.stageCounts.pattern_forming}</p>
          <p>Theory under review: {report.stageCounts.theory_under_review}</p>
          <p>Pattern review unlocked: {report.stageCounts.pattern_review_unlocked}</p>
        </CardContent>
      </Card>

      <Card className="border-violet-500/15 bg-violet-950/10">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-violet-100">Progression rates</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-zinc-400">
          <p>1→2: {rateLabel(report.progressionRates.oneToTwo)}</p>
          <p>2→3: {rateLabel(report.progressionRates.twoToThree)}</p>
          <p>3→4: {rateLabel(report.progressionRates.threeToFour)}</p>
          <p>4→5: {rateLabel(report.progressionRates.fourToFive)}</p>
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
