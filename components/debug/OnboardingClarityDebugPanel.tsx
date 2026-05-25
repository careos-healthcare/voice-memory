"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { OnboardingClarityDebugReport } from "@/types/onboarding-clarity";

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5 border-b border-white/5 py-2 sm:flex-row sm:justify-between">
      <span className="text-xs text-zinc-500">{label}</span>
      <span className="text-sm text-zinc-300">{value}</span>
    </div>
  );
}

export function OnboardingClarityDebugPanel({
  report,
}: {
  report: OnboardingClarityDebugReport;
}) {
  return (
    <div className="space-y-4">
      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">First two minutes</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row
            label="Within 2-minute window"
            value={report.withinTwoMinutes ? "Yes" : "No"}
          />
          <Row
            label="Time to meaningful moment"
            value={
              report.timeToMeaningfulMomentMs === null
                ? "—"
                : `${Math.round(report.timeToMeaningfulMomentMs / 1000)}s`
            }
          />
          <Row
            label="First revisit delay (hours)"
            value={
              report.firstRevisitDelayHours === null
                ? "—"
                : String(Math.round(report.firstRevisitDelayHours))
            }
          />
          <Row label="Revisit conversion" value={report.revisitConversion} />
          <Row label="Confusion level" value={report.confusionLevel} />
        </CardContent>
      </Card>

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Flow steps</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.flowSteps.map((step) => (
            <p key={step.id}>
              <span className="text-zinc-500">{step.label}:</span>{" "}
              {step.completedAt
                ? `done ${step.completedAt.slice(0, 16)}`
                : step.droppedAt
                  ? `dropped ${step.droppedAt.slice(0, 16)}`
                  : "—"}
            </p>
          ))}
        </CardContent>
      </Card>

      {report.dropOffPoints.length > 0 ? (
        <Card className="border-white/[0.06] bg-zinc-900/40">
          <CardHeader>
            <CardTitle className="text-sm font-normal text-zinc-300">Drop-off</CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 text-sm text-amber-200/80">
            {report.dropOffPoints.map((point) => (
              <p key={point}>{point}</p>
            ))}
          </CardContent>
        </Card>
      ) : null}

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Aha & comprehension</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <Row
            label="Hours since first session"
            value={report.ahaTimingHours === null ? "—" : String(Math.round(report.ahaTimingHours))}
          />
          <Row
            label="Active first aha"
            value={report.activeFirstAha ? report.activeFirstAha.text.slice(0, 60) : "—"}
          />
          <Row
            label="Active comprehension"
            value={report.activeComprehension?.text ?? "—"}
          />
          <Row label="Ignored copy count" value={String(report.ignoredCopyCount)} />
        </CardContent>
      </Card>

      {report.confusionSignals.length > 0 ? (
        <Card className="border-white/[0.06] bg-zinc-900/40">
          <CardHeader>
            <CardTitle className="text-sm font-normal text-zinc-300">Confusion signals</CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 text-sm text-zinc-400">
            {report.confusionSignals.map((signal) => (
              <p key={signal}>{signal}</p>
            ))}
          </CardContent>
        </Card>
      ) : null}

      {report.overwhelmingSurfaces.length > 0 ? (
        <Card className="border-white/[0.06] bg-zinc-900/40">
          <CardHeader>
            <CardTitle className="text-sm font-normal text-zinc-300">Overwhelming</CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 text-sm text-rose-200/70">
            {report.overwhelmingSurfaces.map((surface) => (
              <p key={surface}>{surface}</p>
            ))}
          </CardContent>
        </Card>
      ) : null}

      <Card className="border-white/[0.06] bg-zinc-900/40">
        <CardHeader>
          <CardTitle className="text-sm font-normal text-zinc-300">Instrumentation</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-xs text-zinc-500">
          {Object.entries(report.instrumentation)
            .filter(([, count]) => count > 0)
            .map(([name, count]) => (
              <p key={name}>
                {name}: {count}
              </p>
            ))}
        </CardContent>
      </Card>
    </div>
  );
}
