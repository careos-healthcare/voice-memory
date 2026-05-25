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

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5 border-b border-white/5 py-2 sm:flex-row sm:justify-between">
      <span className="text-xs text-zinc-500">{label}</span>
      <span className="text-sm text-zinc-300">{value}</span>
    </div>
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
        <StatCard label="Quality threshold" value={String(report.effects.qualityThresholdRequired)} />
        <StatCard label="Enabled" value={report.enabled ? "Yes" : "No"} />
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base text-zinc-200">Why silence activated</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          <p className="text-zinc-300">{report.activationReason}</p>
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
            <CardTitle className="text-base text-zinc-200">Retention signals</CardTitle>
          </CardHeader>
          <CardContent className="text-sm">
            <Row label="Onboarding aha-rate" value={report.retentionSignals.onboardingAhaRate} />
            <Row
              label="Return after silence"
              value={String(report.retentionSignals.returnAfterSilenceCount)}
            />
            <Row
              label="Reflection during silence"
              value={String(report.retentionSignals.reflectionDuringSilenceCount)}
            />
            <Row
              label="Revisit after silence"
              value={String(report.retentionSignals.revisitAfterSilenceCount)}
            />
            <Row label="Ignored prompts" value={String(report.retentionSignals.ignoredPromptCount)} />
            <Row
              label="High-quality revisit"
              value={
                report.retentionSignals.highQualityRevisitAvailable
                  ? `Yes · ${report.retentionSignals.bestRevisitScore ?? "—"}`
                  : "No"
              }
            />
            <Row
              label="Export / backup during silence"
              value={report.retentionSignals.exportBackupDuringSilence ? "Yes" : "No"}
            />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base text-zinc-200">Silence outcome</CardTitle>
          </CardHeader>
          <CardContent className="text-sm">
            <Row label="Silence helped" value={report.silenceHelped ? "Yes" : "No"} />
            <Row label="Silence harmed" value={report.silenceHarmed ? "Yes" : "No"} />
            <Row label="Return after silence" value={report.returnAfterSilence ? "Yes" : "No"} />
            <Row label="Silence improved revisit" value={improved} />
            <Row label="Reflections during silence" value={String(report.reflectionsDuringSilence)} />
            <Row label="Next resurfacing window" value={report.nextResurfacingWindow ?? "—"} />
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="text-base text-zinc-200">What was suppressed</CardTitle>
          <Button type="button" variant="ghost" size="sm" onClick={onRefresh}>
            <RefreshCw className="h-4 w-4" />
          </Button>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.suppressedSurfaces.length === 0 ? (
            <p>Nothing actively suppressed.</p>
          ) : (
            report.suppressedSurfaces.map((surface) => (
              <p key={surface}>{surface.replace(/_/g, " ")}</p>
            ))
          )}
          <div className="mt-4 grid gap-2 sm:grid-cols-2">
            {Object.entries(report.effects).map(([key, active]) => (
              <p key={key}>
                {key}: {typeof active === "boolean" ? (active ? "on" : "off") : String(active)}
              </p>
            ))}
          </div>
          {report.userLine ? (
            <p className="text-zinc-300">User line: “{report.userLine}”</p>
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
