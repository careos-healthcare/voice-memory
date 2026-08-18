"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type {
  ReturnTriggerCategorySummary,
  ReturnTriggerDebugReport,
  ReturnTriggerReturnRow,
} from "@/types/return-triggers";

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5 border-b border-white/5 py-2 sm:flex-row sm:justify-between">
      <span className="text-xs text-zinc-500">{label}</span>
      <span className="text-sm text-zinc-300">{value}</span>
    </div>
  );
}

function CategoryCard({
  title,
  summary,
}: {
  title: string;
  summary: ReturnTriggerCategorySummary;
}) {
  return (
    <Card className="border-white/[0.06] bg-zinc-900/40">
      <CardHeader>
        <CardTitle className="text-sm font-normal text-zinc-300">{title}</CardTitle>
      </CardHeader>
      <CardContent className="text-sm">
        <Row label="Returns" value={String(summary.count)} />
        <Row
          label="Median hours to return"
          value={summary.medianHoursToReturn === null ? "—" : String(summary.medianHoursToReturn)}
        />
        <Row label="Reflection rate" value={`${summary.reflectionRate}%`} />
        <Row label="Revisit rate" value={`${summary.revisitRate}%`} />
        <Row label="Export / backup rate" value={`${summary.exportOrBackupRate}%`} />
        <Row label="Strength" value={summary.strength} />
      </CardContent>
    </Card>
  );
}

function ReturnRow({ row }: { row: ReturnTriggerReturnRow }) {
  const outcomes = [
    row.ledToReflection ? "reflection" : null,
    row.ledToRevisit ? "revisit" : null,
    row.ledToExportOrBackup ? "export/backup" : null,
  ]
    .filter(Boolean)
    .join(" · ");

  return (
    <div className="border-b border-white/5 py-2 text-sm">
      <p className="text-zinc-300">{row.eventName}</p>
      <p className="mt-1 text-xs text-zinc-500">
        {row.at.slice(0, 16)} · trigger {row.triggerKind ?? "—"} · gap{" "}
        {row.hoursSinceTrigger ?? row.hoursSinceLastOpen ?? "—"}h · {row.window ?? "—"}
      </p>
      <p className="mt-1 text-xs text-zinc-600">
        Outcomes: {outcomes.length > 0 ? outcomes : "none within 24h"}
      </p>
    </div>
  );
}

export function ReturnTriggersDebugPanel({ report }: { report: ReturnTriggerDebugReport }) {
  return (
    <div className="space-y-4">
      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Overview</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Total return events" value={String(report.totalReturns)} />
          <Row label="Prompt-driven returns" value={String(report.promptDrivenCount)} />
          <Row label="Voluntary returns" value={String(report.voluntaryCount)} />
          <Row
            label="Prompt vs voluntary"
            value={
              report.promptDrivenCount + report.voluntaryCount === 0
                ? "—"
                : `${report.promptDrivenCount} prompt · ${report.voluntaryCount} voluntary`
            }
          />
        </CardContent>
      </Card>

      <div className="grid gap-4 md:grid-cols-2">
        <CategoryCard title="Silence-driven returns" summary={report.silenceDriven} />
        <CategoryCard title="Photo-driven returns" summary={report.photoDriven} />
        <CategoryCard title="Territory-driven returns" summary={report.territoryDriven} />
        <CategoryCard title="Revisit-driven returns" summary={report.revisitDriven} />
      </div>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Strongest return triggers</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.strongestTriggers.length === 0 ? (
            <p className="text-zinc-500">Not enough attributed returns yet.</p>
          ) : (
            report.strongestTriggers.map((row) => (
              <p key={row.eventName}>
                {row.kind}: {row.count} returns · {row.reflectionRate}% reflection ·{" "}
                {row.revisitRate}% revisit · {row.strength}
              </p>
            ))
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Weak or noisy triggers</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.weakOrNoisyTriggers.length === 0 ? (
            <p className="text-zinc-500">None flagged yet.</p>
          ) : (
            report.weakOrNoisyTriggers.map((row) => (
              <p key={row.eventName}>
                {row.kind}: {row.count} returns · {row.strength}
              </p>
            ))
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Instrumentation</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-zinc-400">
          {Object.entries(report.instrumentation).map(([name, count]) => (
            <p key={name}>
              <span className="text-zinc-500">{name}:</span> {count}
            </p>
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Recent returns</CardTitle>
        </CardHeader>
        <CardContent>
          {report.recentReturns.length === 0 ? (
            <p className="text-sm text-zinc-500">No return events recorded yet.</p>
          ) : (
            report.recentReturns.map((row) => <ReturnRow key={`${row.eventName}-${row.at}`} row={row} />)
          )}
        </CardContent>
      </Card>
    </div>
  );
}
