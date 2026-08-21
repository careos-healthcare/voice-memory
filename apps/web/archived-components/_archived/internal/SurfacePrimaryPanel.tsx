"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { SurfacePrimaryReport } from "@/types/theory";

interface SurfacePrimaryPanelProps {
  report: SurfacePrimaryReport;
}

export function SurfacePrimaryPanel({ report }: SurfacePrimaryPanelProps) {
  return (
    <div className="space-y-6">
      <Card className="border-violet-500/20 bg-violet-950/15">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-violet-100">Theory change open rate</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-3xl font-semibold text-white">{report.theoryChangeOpenRate}%</p>
          <p className="mt-1 text-xs text-zinc-500">
            discover_opened vs {report.sessionCount} tracked sessions
          </p>
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Surface comparison</CardTitle>
          <p className="text-xs text-zinc-500">
            Open rate, revisit, surprising, uncomfortably accurate, wow — measurement only
          </p>
        </CardHeader>
        <CardContent className="overflow-x-auto">
          <table className="w-full text-left text-sm text-zinc-400">
            <thead>
              <tr className="text-xs uppercase tracking-wider text-zinc-600">
                <th className="pb-2 pr-4">Surface</th>
                <th className="pb-2 pr-4">Opens</th>
                <th className="pb-2 pr-4">Open %</th>
                <th className="pb-2 pr-4">Revisit %</th>
                <th className="pb-2 pr-4">Surprising %</th>
                <th className="pb-2 pr-4">Uncomfortable %</th>
                <th className="pb-2">Wow avg</th>
              </tr>
            </thead>
            <tbody>
              {report.surfaces.map((row) => (
                <tr key={row.surface} className="border-t border-white/5">
                  <td className="py-2 pr-4 text-zinc-300">{row.label}</td>
                  <td className="py-2 pr-4">{row.openCount}</td>
                  <td className="py-2 pr-4">{row.openRate}%</td>
                  <td className="py-2 pr-4">{row.revisitRate}%</td>
                  <td className="py-2 pr-4">{row.surprisingRate}%</td>
                  <td className="py-2 pr-4">{row.uncomfortablyAccurateRate}%</td>
                  <td className="py-2">{row.averageWowScore}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Primary surface signals</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          <p>Highest revisit: {report.highestRevisit ?? "—"}</p>
          <p>Highest surprising: {report.highestSurprising ?? "—"}</p>
          <p>Highest uncomfortably accurate: {report.highestUncomfortablyAccurate ?? "—"}</p>
          <p>Highest wow score: {report.highestWowScore ?? "—"}</p>
          <p className="mt-3 font-medium text-zinc-300">
            Candidate: {report.primarySurfaceCandidate ?? "insufficient data"}
          </p>
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Discovery answers</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          {report.insightLines.map((line) => (
            <p key={line} className="text-sm leading-relaxed text-zinc-500">
              {line}
            </p>
          ))}
        </CardContent>
      </Card>
    </div>
  );
}
