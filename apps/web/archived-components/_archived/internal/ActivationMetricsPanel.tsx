"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { ActivationMetricsReport } from "@/lib/product/activation-metrics";

interface ActivationMetricsPanelProps {
  report: ActivationMetricsReport;
}

export function ActivationMetricsPanel({ report }: ActivationMetricsPanelProps) {
  return (
    <section className="space-y-4 border-t border-white/5 pt-10">
      <div>
        <h2 className="text-lg font-medium text-zinc-200">Activation metrics (local)</h2>
        <p className="mt-1 max-w-2xl text-sm text-zinc-500">
          Three signals only — 5 reflections, Discover/Blind spots opens, Surprising or
          Uncomfortably Accurate reactions. This device only.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">5 reflections</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.fiveReflectionsRate ?? "—"}%
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Discover / blind spots</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.discoveryOpenRate ?? "—"}%
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Strong reaction</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.strongReactionRate ?? "—"}%
            </p>
          </CardContent>
        </Card>
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardContent className="space-y-2 py-4 text-sm text-zinc-400">
          {report.lines.map((line) => (
            <p key={line}>{line}</p>
          ))}
          <p className="text-xs text-zinc-600">
            Current reflections on device: {report.currentReflectionCount}
            {report.hasReachedFiveLocally ? " (≥5)" : ""}
          </p>
        </CardContent>
      </Card>
    </section>
  );
}
