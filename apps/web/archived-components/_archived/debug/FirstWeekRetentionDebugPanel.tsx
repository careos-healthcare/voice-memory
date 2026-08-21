"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { FirstWeekRetentionDebugReport } from "@/types/first-week-retention";

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5 border-b border-white/5 py-2 sm:flex-row sm:justify-between">
      <span className="text-xs text-zinc-500">{label}</span>
      <span className="text-sm text-zinc-300">{value}</span>
    </div>
  );
}

export function FirstWeekRetentionDebugPanel({
  report,
}: {
  report: FirstWeekRetentionDebugReport;
}) {
  return (
    <div className="space-y-4">
      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">First week window</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Within first week" value={report.withinFirstWeek ? "Yes" : "No"} />
          <Row label="Day index" value={report.dayIndex === null ? "—" : String(report.dayIndex)} />
          <Row label="First session complete" value={report.firstSessionComplete ? "Yes" : "No"} />
          <Row
            label="First revisit delay (hours)"
            value={
              report.firstRevisitDelayHours === null
                ? "—"
                : String(report.firstRevisitDelayHours)
            }
          />
          <Row label="Revisit conversion" value={report.revisitConversion} />
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Milestones</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.milestones.map((milestone) => (
            <p key={milestone.id}>
              <span className="text-zinc-500">{milestone.id}:</span>{" "}
              {milestone.reachedAt ? milestone.reachedAt.slice(0, 16) : "—"} · {milestone.evidence}
            </p>
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Attachment & prompts</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row label="Attachment" value={report.attachmentEmergence} />
          <Row label="Ignored prompts" value={String(report.ignoredPromptCount)} />
          <Row label="Prompts shown (week)" value={String(report.promptsShownThisWeek)} />
          <Row label="Silence effective" value={report.silenceEffective ? "Yes" : "No"} />
          {report.activeGentlePrompt ? (
            <p className="mt-2 text-zinc-400">Active prompt: {report.activeGentlePrompt.text}</p>
          ) : null}
          {report.activeArchiveValueLine ? (
            <p className="mt-1 text-zinc-500">Archive line: {report.activeArchiveValueLine.text}</p>
          ) : null}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Timing recommendations</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.timingRecommendations.length === 0 ? (
            <p className="text-zinc-500">None</p>
          ) : (
            report.timingRecommendations.map((rec) => (
              <p key={`${rec.action}-${rec.priority}`}>
                {rec.action} ({rec.priority}) — {rec.reason}
              </p>
            ))
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Retention risks</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-zinc-400">
          {report.retentionRisks.map((risk) => (
            <p key={risk}>· {risk}</p>
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Emotional payoff candidates</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.emotionalPayoffCandidates.length === 0 ? (
            <p className="text-zinc-500">None ranked</p>
          ) : (
            report.emotionalPayoffCandidates.map((row) => (
              <p key={row.entryId}>
                {row.entryId.slice(0, 8)} · score {row.score} · {row.firstLine}
              </p>
            ))
          )}
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Instrumentation</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-zinc-500">
          {Object.entries(report.instrumentation).map(([name, count]) => (
            <p key={name}>
              {name}: {count}
            </p>
          ))}
        </CardContent>
      </Card>
    </div>
  );
}
