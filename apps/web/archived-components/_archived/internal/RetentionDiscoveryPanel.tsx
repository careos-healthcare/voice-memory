"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { RETURN_REASON_LABELS } from "@/lib/retention/return-reason-survey";
import { returnReasonBySessionBucket } from "@/lib/retention/retention-discovery-report";
import type { RetentionDiscoveryReport } from "@/types/retention-discovery";

const BUCKET_LABELS: Record<string, string> = {
  session_1: "Session 1",
  session_2_3: "Sessions 2–3",
  session_4_plus: "Session 4+",
};

interface RetentionDiscoveryPanelProps {
  report: RetentionDiscoveryReport;
}

export function RetentionDiscoveryPanel({ report }: RetentionDiscoveryPanelProps) {
  const byBucket = returnReasonBySessionBucket();

  return (
    <div className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Return rate</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.signalScore.returnRate}%</p>
            <p className="mt-1 text-xs text-zinc-600">
              {report.signalScore.returnReasonCount} reasons / {report.signalScore.sessionCount}{" "}
              sessions
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Avg wow score</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.signalScore.averageWowScore}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Avg helpfulness</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.signalScore.averageHelpfulness}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Breakthrough rate</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.signalScore.breakthroughRate}%
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Abandonment signal</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.signalScore.abandonmentSignalRate}%
            </p>
            <p className="mt-1 text-xs text-zinc-600">“Not really” outcomes</p>
          </CardContent>
        </Card>
      </div>

      <Card className="border-violet-500/20 bg-violet-950/15">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-violet-100">Time to first value</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          <p>
            {report.firstValue.timeToFirstValueDays !== null
              ? `${report.firstValue.timeToFirstValueDays} days — ${report.firstValue.timeToFirstValueKind}`
              : "No first value moment recorded yet."}
          </p>
          {report.firstValue.moments.length > 0 ? (
            <ul className="space-y-1">
              {report.firstValue.moments.map((m) => (
                <li key={m.kind}>
                  {m.kind} · day {m.daysSinceFirstVisit}
                </li>
              ))}
            </ul>
          ) : null}
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Return reasons (all)</CardTitle>
          <p className="text-xs text-zinc-500">
            By wow (same-day reactions), helpfulness (matched session), archive size at capture
          </p>
        </CardHeader>
        <CardContent className="space-y-2">
          {report.returnReasons.length === 0 ? (
            <p className="text-sm text-zinc-600">No return reasons yet.</p>
          ) : (
            report.returnReasons.map((row) => (
              <p key={row.reason} className="text-sm text-zinc-400">
                <span className="text-zinc-200">{row.label}</span> — {row.count} ({row.share}%) ·
                wow {row.averageWowScore} · helpful {row.averageHelpfulness} · archive{" "}
                {row.averageArchiveSize}
              </p>
            ))
          )}
          {report.mostCommonReturnReason ? (
            <p className="mt-3 text-xs text-zinc-500">
              Most common: {RETURN_REASON_LABELS[report.mostCommonReturnReason]}
            </p>
          ) : null}
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-3">
        {Object.entries(byBucket).map(([bucket, rows]) => (
          <Card key={bucket} className="border-white/10 bg-zinc-900/50">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm text-zinc-300">{BUCKET_LABELS[bucket]}</CardTitle>
            </CardHeader>
            <CardContent className="space-y-1 text-sm text-zinc-500">
              {rows.length === 0 ? (
                <p className="text-zinc-600">No data</p>
              ) : (
                rows.map((row) => (
                  <p key={row.reason}>
                    {row.label}: {row.count}
                  </p>
                ))
              )}
            </CardContent>
          </Card>
        ))}
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Discovery answers</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {report.insights.map((line) => (
            <div key={line.question}>
              <p className="text-sm font-medium text-zinc-300">{line.question}</p>
              <p className="mt-1 text-sm leading-relaxed text-zinc-500">{line.answer}</p>
            </div>
          ))}
        </CardContent>
      </Card>
    </div>
  );
}
