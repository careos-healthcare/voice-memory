"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { FounderTestReport } from "@/types/founder-test";

interface FounderTestReportPanelProps {
  report: FounderTestReport;
}

function rateLabel(value: number | null): string {
  return value === null ? "—" : `${value}%`;
}

function signalStyles(signal: FounderTestReport["studySignal"]): string {
  switch (signal) {
    case "strong_signal":
      return "border-emerald-500/25 bg-emerald-950/15 text-emerald-100";
    case "weak_signal":
      return "border-red-500/25 bg-red-950/15 text-red-100";
    default:
      return "border-amber-500/25 bg-amber-950/15 text-amber-100";
  }
}

export function FounderTestReportPanel({ report }: FounderTestReportPanelProps) {
  return (
    <section className="space-y-6">
      <Card className={`border ${signalStyles(report.studySignal)}`}>
        <CardHeader className="pb-2">
          <CardTitle className="text-base">Study signal: {report.studySignal}</CardTitle>
          <p className="text-sm text-zinc-400">{report.studySignalLabel}</p>
        </CardHeader>
      </Card>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Reach 5 reflections</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{rateLabel(report.reachedFiveRate)}</p>
            <p className="mt-1 text-xs text-zinc-600">n={report.totalParticipants}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Blind spot opened</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {rateLabel(report.blindSpotOpenRate)}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Discover opened</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {rateLabel(report.discoverOpenRate)}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Strong reaction</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {rateLabel(report.surprisingOrAccurateRate)}
            </p>
            <p className="mt-1 text-xs text-zinc-600">Surprising or uncomfortably accurate</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">7-day return</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {rateLabel(report.sevenDayReturnRate)}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">ChatGPT difference</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {rateLabel(report.chatGptDifferenceUnderstoodRate)}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Would pay</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{rateLabel(report.wouldPayRate)}</p>
          </CardContent>
        </Card>
      </div>

      <Card className="border-red-500/15 bg-red-950/10">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-red-100">Red flags</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-300">
          {report.redFlags.length === 0 ? (
            <p className="text-zinc-600">None flagged yet.</p>
          ) : (
            report.redFlags.map((flag) => (
              <p key={`${flag.participantId}-${flag.reason}`}>
                <span className="text-zinc-200">{flag.label}</span>: {flag.reason}
              </p>
            ))
          )}
        </CardContent>
      </Card>

      <Card className="border-violet-500/15 bg-violet-950/10">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-violet-100">Strongest quotes</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm italic text-zinc-300">
          {report.strongestQuotes.length === 0 ? (
            <p className="text-zinc-600 not-italic">Add main quotes per participant.</p>
          ) : (
            report.strongestQuotes.map((quote) => (
              <p key={quote}>&ldquo;{quote}&rdquo;</p>
            ))
          )}
        </CardContent>
      </Card>
    </section>
  );
}
