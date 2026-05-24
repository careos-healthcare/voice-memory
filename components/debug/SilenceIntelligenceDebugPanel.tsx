"use client";

import { RefreshCw } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { SilenceIntelligenceDebugReport } from "@/types/silence-intelligence";

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <Card>
      <CardHeader className="pb-1">
        <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
          {label}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-semibold tabular-nums text-white">{value}</p>
      </CardContent>
    </Card>
  );
}

export function SilenceIntelligenceDebugPanel({
  report,
  onRefresh,
}: {
  report: SilenceIntelligenceDebugReport;
  onRefresh: () => void;
}) {
  const improved =
    report.silenceImprovedRevisit === null
      ? "Unknown"
      : report.silenceImprovedRevisit
        ? "Yes"
        : "No";

  return (
    <div className="space-y-6">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="State" value={report.state.replace(/_/g, " ")} />
        <StatCard label="Score" value={String(report.score)} />
        <StatCard label="Ignored notes" value={String(report.ignoredNoteCount)} />
        <StatCard label="Enabled" value={report.enabled ? "Yes" : "No"} />
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base text-zinc-200">Reasons</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.signals.length === 0 ? (
            <p>No active silence signals.</p>
          ) : (
            report.signals.map((signal) => (
              <div key={signal.id} className="rounded-lg border border-white/5 px-3 py-2">
                <p className="font-medium text-zinc-300">{signal.label}</p>
                <p className="mt-1 text-zinc-500">{signal.detail}</p>
              </div>
            ))
          )}
        </CardContent>
      </Card>

      <div className="grid gap-3 sm:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-base text-zinc-200">Last surfaced note</CardTitle>
          </CardHeader>
          <CardContent className="text-sm text-zinc-400">
            {report.lastSurfacedNoteId ? (
              <>
                <p className="font-mono text-xs text-zinc-500">{report.lastSurfacedNoteId}</p>
                {report.lastSurfacedNoteAt ? (
                  <p className="mt-2 text-zinc-500">{report.lastSurfacedNoteAt}</p>
                ) : null}
              </>
            ) : (
              <p>None recorded.</p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base text-zinc-200">Return & revisit</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-400">
            <p>Return after silence: {report.returnAfterSilence ? "Yes" : "No"}</p>
            <p>Silence improved revisit behavior: {improved}</p>
            <p>Reflections during silence: {report.reflectionsDuringSilence}</p>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="text-base text-zinc-200">Effects</CardTitle>
          <Button type="button" variant="ghost" size="sm" onClick={onRefresh}>
            <RefreshCw className="h-4 w-4" />
          </Button>
        </CardHeader>
        <CardContent className="grid gap-2 text-sm text-zinc-400 sm:grid-cols-2">
          {Object.entries(report.effects).map(([key, active]) => (
            <p key={key}>
              {key}: {active ? "on" : "off"}
            </p>
          ))}
          {report.userLine ? (
            <p className="sm:col-span-2 text-zinc-300">User line: “{report.userLine}”</p>
          ) : null}
        </CardContent>
      </Card>

      {report.recentStateTransitions.length > 0 ? (
        <Card>
          <CardHeader>
            <CardTitle className="text-base text-zinc-200">Recent transitions</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-500">
            {report.recentStateTransitions
              .slice()
              .reverse()
              .map((row) => (
                <p key={`${row.at}-${row.from}-${row.to}`}>
                  {row.from} → {row.to} · {row.at}
                </p>
              ))}
          </CardContent>
        </Card>
      ) : null}
    </div>
  );
}
