"use client";

import type { ReturnTriggerAttributionReport } from "@/types/return-trigger-attribution";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";

interface ReturnTriggerPanelProps {
  report: ReturnTriggerAttributionReport;
}

export function ReturnTriggerPanel({ report }: ReturnTriggerPanelProps) {
  return (
    <div className="space-y-6">
      <Card className="border-amber-500/25 bg-zinc-900/50">
        <CardHeader>
          <CardTitle className="text-lg text-white">Critical report</CardTitle>
          <p className="text-sm font-medium text-amber-200/90">{report.criticalQuestion}</p>
        </CardHeader>
        <CardContent>
          <p className="text-sm leading-relaxed text-zinc-300">{report.criticalAnswer}</p>
          <p className="mt-3 text-xs text-zinc-500">
            {report.totalReasonResponses} reason response
            {report.totalReasonResponses === 1 ? "" : "s"} · {report.totalExpectationResponses}{" "}
            expectation response
            {report.totalExpectationResponses === 1 ? "" : "s"} on this device
          </p>
        </CardContent>
      </Card>

      <Card className="border-violet-500/20 bg-zinc-900/50">
        <CardHeader>
          <CardTitle className="text-lg text-white">Return trigger attribution</CardTitle>
          <p className="text-sm text-zinc-400">
            Self-reported return intent — correlated with 7-day activity, paywall, subscription
            signals, and breakthrough captures on this device.
          </p>
        </CardHeader>
        <CardContent className="space-y-4 text-sm">
          <div>
            <p className="text-xs uppercase tracking-wider text-zinc-500">Most common return reason</p>
            <p className="mt-1 text-zinc-200">
              {report.mostCommonReasonLabel ?? "—"}
              {report.mostCommonReason ? (
                <span className="text-zinc-500"> ({report.mostCommonReason})</span>
              ) : null}
            </p>
          </div>

          {report.byReason.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[640px] text-left text-xs">
                <thead>
                  <tr className="border-b border-zinc-800 text-zinc-500">
                    <th className="py-2 pr-3 font-normal">Reason</th>
                    <th className="py-2 pr-3 font-normal">n</th>
                    <th className="py-2 pr-3 font-normal">Share</th>
                    <th className="py-2 pr-3 font-normal">7d activity</th>
                    <th className="py-2 pr-3 font-normal">Paywall</th>
                    <th className="py-2 pr-3 font-normal">Subscribe</th>
                    <th className="py-2 pr-3 font-normal">Breakthrough</th>
                  </tr>
                </thead>
                <tbody>
                  {report.byReason.map((row) => (
                    <tr key={row.reason} className="border-b border-zinc-800/60 text-zinc-300">
                      <td className="py-2 pr-3">{row.label}</td>
                      <td className="py-2 pr-3 tabular-nums">{row.count}</td>
                      <td className="py-2 pr-3 tabular-nums">{row.sharePercent}%</td>
                      <td className="py-2 pr-3 tabular-nums">
                        {row.sevenDayRetentionRate ?? "—"}
                        {row.sevenDayRetentionRate !== null ? "%" : ""}
                      </td>
                      <td className="py-2 pr-3 tabular-nums">
                        {row.paywallClickRate ?? "—"}
                        {row.paywallClickRate !== null ? "%" : ""}
                      </td>
                      <td className="py-2 pr-3 tabular-nums">
                        {row.subscriptionRate ?? "—"}
                        {row.subscriptionRate !== null ? "%" : ""}
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
          ) : (
            <p className="text-zinc-500">No return reason responses yet.</p>
          )}

          {report.expectationBreakdown.length > 0 ? (
            <div>
              <p className="text-xs uppercase tracking-wider text-zinc-500">
                Did they find what they were looking for?
              </p>
              <ul className="mt-2 space-y-1 text-zinc-400">
                {report.expectationBreakdown.map((row) => (
                  <li key={row.met}>
                    {row.met}: {row.count} ({row.sharePercent}%)
                  </li>
                ))}
              </ul>
            </div>
          ) : null}
        </CardContent>
      </Card>
    </div>
  );
}
