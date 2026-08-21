"use client";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  buildObservationSummariesExport,
  downloadObservationSummariesJson,
} from "@/lib/validation/observation-summaries";
import type { ObservationSummariesExport } from "@/types/validation-phase";

function RankedList({
  title,
  items,
}: {
  title: string;
  items: Array<{ id: string; label: string; detail?: string }>;
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-200">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        {items.length === 0 ? (
          <p className="text-sm text-zinc-500">Nothing recorded yet.</p>
        ) : (
          <ol className="space-y-2">
            {items.map((item, index) => (
              <li key={item.id} className="rounded-lg bg-white/[0.03] px-3 py-2 text-sm">
                <p className="text-zinc-200">
                  <span className="tabular-nums text-zinc-600">{index + 1}.</span> {item.label}
                </p>
                {item.detail ? <p className="mt-1 text-xs text-zinc-600">{item.detail}</p> : null}
              </li>
            ))}
          </ol>
        )}
      </CardContent>
    </Card>
  );
}

export function FounderReviewPanel({
  report,
  summaries,
}: {
  report: import("@/types/validation-phase").FounderReviewReport;
  summaries: ObservationSummariesExport | null;
}) {
  return (
    <div className="space-y-6">
      <Card className={report.monetizationVerdict === "test_carefully" ? "border-emerald-900/40" : "border-amber-900/40"}>
        <CardHeader className="pb-2">
          <CardTitle className="text-lg font-normal text-zinc-100">{report.monetizationHeadline}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          <p>
            {report.openIncidents} open incident(s) · {report.testerFeedbackCount} tester feedback note(s)
          </p>
          <p>
            Premium state: {report.premiumState} · Archive protection interest:{" "}
            {report.archiveProtectionInterest}
          </p>
          <p>
            Premium lines seen: {report.archiveValueObservation.premiumLinesSeen} · Legitimacy{" "}
            {report.archiveValueObservation.legitimacyBeforeExposure ?? "—"} →{" "}
            {report.archiveValueObservation.legitimacyAfterExposure ?? "—"}
          </p>
          <Button
            type="button"
            size="sm"
            variant="secondary"
            onClick={async () => {
              const payload = summaries ?? (await buildObservationSummariesExport());
              downloadObservationSummariesJson(payload);
            }}
          >
            Export observation summaries JSON
          </Button>
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        <RankedList title="Strongest callbacks" items={report.strongestCallbacks} />
        <RankedList title="Dead callbacks" items={report.deadCallbacks} />
        <RankedList title="Strongest revisit moments" items={report.strongestRevisitMoments} />
        <RankedList title="Emotional residue leaders" items={report.emotionalResidueLeaders} />
      </div>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Trust failures</CardTitle>
        </CardHeader>
        <CardContent>
          {report.trustFailures.length === 0 ? (
            <p className="text-sm text-emerald-300/80">No blocking trust failures detected.</p>
          ) : (
            <ul className="space-y-2">
              {report.trustFailures.map((row) => (
                <li key={row.id} className="rounded-lg bg-white/[0.03] px-3 py-2 text-sm text-zinc-400">
                  <p className="text-rose-200/90">{row.label}</p>
                  {row.detail ? <p className="mt-1 text-xs text-zinc-600">{row.detail}</p> : null}
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Sync health</CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="space-y-1 text-sm text-zinc-400">
            {report.syncHealthSummary.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Retention trend (weekly snapshots)</CardTitle>
        </CardHeader>
        <CardContent>
          {report.retentionTrend.length === 0 ? (
            <p className="text-sm text-zinc-500">No weekly snapshots yet — export summaries to capture one.</p>
          ) : (
            <ul className="space-y-2">
              {report.retentionTrend.map((week) => (
                <li key={week.weekStart} className="rounded-lg bg-white/[0.03] px-3 py-2 text-sm text-zinc-400">
                  <p className="font-medium text-zinc-200">Week {week.weekStart}</p>
                  <p className="mt-1 text-xs text-zinc-600">
                    {week.reflectionCount} reflections · {week.returnDayCount} return days ·{" "}
                    {week.oldEntryRevisits} revisits · {week.revisitToReflection} revisit→reflection · D7{" "}
                    {week.day7Returns}
                  </p>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>

      {summaries ? (
        <div className="grid gap-4 lg:grid-cols-2">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-normal text-zinc-200">Callback survival summary</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="space-y-2 text-sm text-zinc-400">
                {summaries.callbackSurvival.slice(0, 8).map((row) => (
                  <li key={row.id} className="rounded-lg bg-white/[0.03] px-3 py-2">
                    <p className="line-clamp-2 text-zinc-200">{row.text}</p>
                    <p className="mt-1 text-xs text-zinc-600">
                      survival {row.survivalScore} · residue {row.residueScore}
                      {row.pruningAction ? ` · ${row.pruningAction}` : ""}
                    </p>
                  </li>
                ))}
              </ul>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-normal text-zinc-200">Revisit conversion</CardTitle>
            </CardHeader>
            <CardContent className="space-y-1 text-sm text-zinc-400">
              <p>Memory clicks: {summaries.revisitConversion.memoryNoteClicks}</p>
              <p>Old entry opens: {summaries.revisitConversion.oldEntryOpens}</p>
              <p>Revisits: {summaries.revisitConversion.revisits}</p>
              <p>Follow-ups: {summaries.revisitConversion.followupsCompleted}/{summaries.revisitConversion.followupsStarted}</p>
              <p>Revisit → reflection: {summaries.revisitConversion.revisitToReflection} ({summaries.revisitConversion.conversionRate})</p>
            </CardContent>
          </Card>
        </div>
      ) : null}
    </div>
  );
}
