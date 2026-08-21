"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { PerformanceHealthReport } from "@/lib/debug/performance-health";

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5 border-b border-white/5 py-2 sm:flex-row sm:justify-between">
      <span className="text-xs text-zinc-500">{label}</span>
      <span className="text-sm text-zinc-300">{value}</span>
    </div>
  );
}

export function PerformanceHealthPanel({ report }: { report: PerformanceHealthReport }) {
  return (
    <div className="space-y-4">
      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Runtime</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Lightweight mode" value={report.lightweightMode ? "Active" : "Off"} />
          <Row label="Entries in archive" value={String(report.entriesCount)} />
          <Row label="Entries cache version" value={String(report.entriesCacheVersion)} />
          <Row
            label="localStorage estimate"
            value={`${Math.round(report.localStorageBytesEstimate / 1024)} KB`}
          />
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Analytics</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Queued events (not flushed)" value={String(report.analyticsQueueSize)} />
          <Row label="Stored events" value={String(report.analyticsEventCount)} />
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Render counts</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          {report.renderCounts.length === 0 ? (
            <p className="text-zinc-500">No render samples yet — open an entry page first.</p>
          ) : (
            report.renderCounts.map((row) => (
              <Row key={row.surface} label={row.surface} value={String(row.count)} />
            ))
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Slowest modules</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          {report.slowestModules.length === 0 ? (
            <p className="text-zinc-500">No timing samples yet.</p>
          ) : (
            report.slowestModules.map((row) => (
              <Row
                key={row.label}
                label={row.label}
                value={`${row.durationMs} ms`}
              />
            ))
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Largest localStorage keys</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          {report.largestLocalKeys.map((row) => (
            <Row
              key={row.key}
              label={row.key}
              value={`${Math.round(row.bytes / 1024)} KB`}
            />
          ))}
        </CardContent>
      </Card>
    </div>
  );
}
