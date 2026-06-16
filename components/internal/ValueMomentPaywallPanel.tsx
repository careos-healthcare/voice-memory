"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { ValueMomentPaywallMetricsReport } from "@/types/value-moment-paywall";

function rateLabel(value: number | null): string {
  return value === null ? "—" : `${value}%`;
}

interface ValueMomentPaywallPanelProps {
  report: ValueMomentPaywallMetricsReport;
}

export function ValueMomentPaywallPanel({ report }: ValueMomentPaywallPanelProps) {
  return (
    <section className="space-y-6 border-t border-white/5 pt-10">
      <div>
        <h2 className="text-lg font-medium text-zinc-200">Value-moment paywall</h2>
        <p className="mt-1 max-w-2xl text-sm text-zinc-500">
          Shown after first blind spot and discover proof — local events on this device only.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Shown</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.shownCount}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">CTA clicks</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.ctaClickedCount}</p>
            <p className="mt-1 text-xs text-zinc-600">Rate: {rateLabel(report.ctaClickRate)}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Dismissed</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.dismissedCount}</p>
            <p className="mt-1 text-xs text-zinc-600">Rate: {rateLabel(report.dismissRate)}</p>
          </CardContent>
        </Card>
      </div>

      <Card className="border-violet-500/15 bg-violet-950/10">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-violet-100">Surface breakdown</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-zinc-400">
          <p>Blind spot: {report.surfaceBreakdown.blind_spot}</p>
          <p>Discover: {report.surfaceBreakdown.discover}</p>
          <p>Archive continuity: {report.surfaceBreakdown.archive_continuity}</p>
          <p className="pt-2 text-xs text-zinc-600">
            Conversion proxy: {rateLabel(report.conversionProxyPercent)}
          </p>
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
