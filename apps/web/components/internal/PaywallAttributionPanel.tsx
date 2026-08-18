"use client";

import type { PaywallAttributionReport } from "@/types/paywall-attribution";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

function ReasonTable({
  title,
  rows,
  showSubscription,
}: {
  title: string;
  rows: PaywallAttributionReport["topRejectionReasons"];
  showSubscription?: boolean;
}) {
  if (rows.length === 0) {
    return <p className="text-sm text-zinc-500">No {title.toLowerCase()} yet.</p>;
  }

  return (
    <div className="overflow-x-auto">
      <p className="mb-2 text-xs uppercase tracking-wider text-zinc-500">{title}</p>
      <table className="w-full min-w-[560px] text-left text-xs">
        <thead>
          <tr className="border-b border-zinc-800 text-zinc-500">
            <th className="py-2 pr-3 font-normal">Reason</th>
            <th className="py-2 pr-3 font-normal">n</th>
            <th className="py-2 pr-3 font-normal">Share</th>
            {showSubscription ? (
              <th className="py-2 pr-3 font-normal">Subscribe rate</th>
            ) : null}
            <th className="py-2 pr-3 font-normal">7d activity</th>
            <th className="py-2 pr-3 font-normal">Breakthrough</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.reason} className="border-b border-zinc-800/60 text-zinc-300">
              <td className="py-2 pr-3">{row.label}</td>
              <td className="py-2 pr-3 tabular-nums">{row.count}</td>
              <td className="py-2 pr-3 tabular-nums">{row.sharePercent}%</td>
              {showSubscription ? (
                <td className="py-2 pr-3 tabular-nums">
                  {row.subscriptionRate ?? "—"}
                  {row.subscriptionRate !== null ? "%" : ""}
                </td>
              ) : null}
              <td className="py-2 pr-3 tabular-nums">
                {row.retentionRate ?? "—"}
                {row.retentionRate !== null ? "%" : ""}
              </td>
              <td className="py-2 pr-3 tabular-nums">
                {row.breakthroughRate ?? "—"}
                {row.breakthroughRate !== null ? "%" : ""}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

interface PaywallAttributionPanelProps {
  report: PaywallAttributionReport;
}

export function PaywallAttributionPanel({ report }: PaywallAttributionPanelProps) {
  return (
    <div className="space-y-6">
      <Card className="border-emerald-500/25 bg-zinc-900/50">
        <CardHeader>
          <CardTitle className="text-lg text-white">{report.mainQuestion}</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm leading-relaxed text-zinc-300">{report.mainAnswer}</p>
          <p className="mt-3 text-xs text-zinc-500">
            {report.totalRejections} rejections · {report.totalInterest} interest signals ·{" "}
            {report.totalConversions} conversion responses (device-local)
          </p>
        </CardContent>
      </Card>

      <Card className="border-violet-500/20 bg-zinc-900/50">
        <CardHeader>
          <CardTitle className="text-lg text-white">Paywall attribution</CardTitle>
        </CardHeader>
        <CardContent className="space-y-6">
          <ReasonTable title="Top conversion drivers" rows={report.topConversionDrivers} />
          <ReasonTable title="Top rejection reasons" rows={report.topRejectionReasons} />
          <ReasonTable
            title="Interest → subscription (30d proxy)"
            rows={report.interestByOutcome}
            showSubscription
          />
        </CardContent>
      </Card>
    </div>
  );
}
