"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { ActivationBottleneckMetricsReport } from "@/lib/product/activation-bottleneck-metrics";

interface ActivationBottleneckPanelProps {
  report: ActivationBottleneckMetricsReport;
}

export function ActivationBottleneckPanel({ report }: ActivationBottleneckPanelProps) {
  return (
    <Card className="border-amber-500/20 bg-amber-950/10">
      <CardHeader className="pb-2">
        <CardTitle className="text-base text-amber-100">4 → 5 activation bottleneck</CardTitle>
        <p className="text-xs text-zinc-500">
          Theory preview and first blind spot simulator at reflections 3–4 — local events on this
          device only.
        </p>
      </CardHeader>
      <CardContent className="space-y-3">
        <div className="grid gap-3 sm:grid-cols-3">
          <div>
            <p className="text-xs text-zinc-500">Reached 4</p>
            <p className="text-xl font-semibold text-white">{report.totalReached4}</p>
          </div>
          <div>
            <p className="text-xs text-zinc-500">Reached 5</p>
            <p className="text-xl font-semibold text-white">{report.totalReached5}</p>
          </div>
          <div>
            <p className="text-xs text-zinc-500">4→5 conversion</p>
            <p className="text-xl font-semibold text-white">
              {report.reflection4To5ConversionRate ?? "—"}%
            </p>
          </div>
        </div>
        <div className="grid gap-3 sm:grid-cols-2 border-t border-white/5 pt-3">
          <div>
            <p className="text-xs text-zinc-500">Preview shown</p>
            <p className="text-lg font-medium text-zinc-200">{report.previewShownCount}</p>
          </div>
          <div>
            <p className="text-xs text-zinc-500">Preview clicked</p>
            <p className="text-lg font-medium text-zinc-200">{report.previewClickCount}</p>
          </div>
        </div>
        <div className="grid gap-3 sm:grid-cols-3 border-t border-white/5 pt-3">
          <div>
            <p className="text-xs text-zinc-500">Simulator shown</p>
            <p className="text-lg font-medium text-zinc-200">{report.simulatorShownCount}</p>
          </div>
          <div>
            <p className="text-xs text-zinc-500">Example opened</p>
            <p className="text-lg font-medium text-zinc-200">
              {report.simulatorExampleOpenedCount}
            </p>
          </div>
          <div>
            <p className="text-xs text-zinc-500">Simulator CTA</p>
            <p className="text-lg font-medium text-zinc-200">{report.simulatorCtaClickedCount}</p>
          </div>
        </div>
        <div className="grid gap-3 sm:grid-cols-2 border-t border-white/5 pt-3">
          <div>
            <p className="text-xs text-zinc-500">4→5 with simulator</p>
            <p className="text-lg font-medium text-zinc-200">
              {report.conversionWithSimulatorRate ?? "—"}%
            </p>
            <p className="text-[11px] text-zinc-600">
              {report.reached5AfterSimulatorShown}/{report.reached4WithSimulatorShown} cohort
            </p>
          </div>
          <div>
            <p className="text-xs text-zinc-500">4→5 without simulator</p>
            <p className="text-lg font-medium text-zinc-200">
              {report.conversionWithoutSimulatorRate ?? "—"}%
            </p>
            <p className="text-[11px] text-zinc-600">
              {report.reached5WithoutSimulatorShown}/{report.reached4WithoutSimulatorShown} cohort
            </p>
          </div>
        </div>
        <ul className="space-y-1 border-t border-white/5 pt-3 text-xs text-zinc-500">
          {report.lines.map((line) => (
            <li key={line}>{line}</li>
          ))}
        </ul>
      </CardContent>
    </Card>
  );
}
