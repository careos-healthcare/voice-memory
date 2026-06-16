"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { NotificationEffectivenessReport } from "@/types/notification-effectiveness";

interface NotificationEffectivenessPanelProps {
  report: NotificationEffectivenessReport;
}

function rateLabel(value: number | null): string {
  return value === null ? "—" : `${value}%`;
}

export function NotificationEffectivenessPanel({
  report,
}: NotificationEffectivenessPanelProps) {
  return (
    <section className="space-y-6 border-t border-white/5 pt-10">
      <div>
        <h2 className="text-lg font-medium text-zinc-200">Notification effectiveness</h2>
        <p className="mt-1 max-w-2xl text-sm text-zinc-500">
          Local lifecycle and return attribution for theory notifications — open rates,
          24h return behavior, and dead-notification flags.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Total</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{report.totalNotifications}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Open rate</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{rateLabel(report.openRate)}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Return rate (24h)</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {rateLabel(report.notificationReturnRate)}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Insight rate (24h)</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {rateLabel(report.notificationToInsightRate)}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Dismiss rate</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">{rateLabel(report.dismissRate)}</p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Avg time to open</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.averageTimeToOpenHours === null
                ? "—"
                : `${report.averageTimeToOpenHours}h`}
            </p>
          </CardContent>
        </Card>
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Lifecycle events</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-zinc-400">
          {(
            Object.entries(report.lifecycleEventCounts) as Array<
              [string, number]
            >
          ).map(([name, count]) => (
            <p key={name}>
              {name}: {count}
            </p>
          ))}
          <p className="mt-2 text-xs text-zinc-600">
            Strongest type (open): {report.strongestNotificationType ?? "—"} · Weakest:{" "}
            {report.weakestNotificationType ?? "—"}
          </p>
        </CardContent>
      </Card>

      <Card className="border-violet-500/20 bg-violet-950/15">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-violet-100">
            {report.winningReportTitle}
          </CardTitle>
        </CardHeader>
        <CardContent className="grid gap-6 lg:grid-cols-3">
          <div>
            <p className="text-xs uppercase tracking-wide text-zinc-500">By open rate</p>
            <ul className="mt-2 space-y-1 text-sm text-zinc-400">
              {report.winningByOpenRate.slice(0, 7).map((row) => (
                <li key={`open-${row.type}`}>
                  {row.type}: {rateLabel(row.openRate)} ({row.opened}/{row.total})
                </li>
              ))}
            </ul>
          </div>
          <div>
            <p className="text-xs uppercase tracking-wide text-zinc-500">By return rate</p>
            <ul className="mt-2 space-y-1 text-sm text-zinc-400">
              {report.winningByReturnRate.slice(0, 7).map((row) => (
                <li key={`return-${row.type}`}>
                  {row.type}: {rateLabel(row.returnRate)} ({row.returnWithin24h}/{row.opened})
                </li>
              ))}
            </ul>
          </div>
          <div>
            <p className="text-xs uppercase tracking-wide text-zinc-500">By insight rate</p>
            <ul className="mt-2 space-y-1 text-sm text-zinc-400">
              {report.winningByInsightRate.slice(0, 7).map((row) => (
                <li key={`insight-${row.type}`}>
                  {row.type}: {rateLabel(row.insightRate)} ({row.insightWithin24h}/{row.opened})
                </li>
              ))}
            </ul>
          </div>
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-300">Best-performing copy</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm text-zinc-500">
            {report.bestCopy.length === 0 ? (
              <p className="text-zinc-600">No notifications yet</p>
            ) : (
              report.bestCopy.map((row) => (
                <div key={`${row.type}-${row.title}`}>
                  <p className="text-zinc-300">{row.title}</p>
                  <p className="text-xs text-zinc-600">
                    {row.type} · open {rateLabel(row.openRate)} · return {rateLabel(row.returnRate)}
                  </p>
                </div>
              ))
            )}
          </CardContent>
        </Card>
        <Card className="border-amber-500/20 bg-amber-950/15">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-amber-100">Potential dead notification</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-500">
            {report.deadNotifications.length === 0 ? (
              <p className="text-zinc-600">None flagged</p>
            ) : (
              report.deadNotifications.slice(0, 12).map((flag) => (
                <p key={`${flag.reason}-${flag.notificationId}`}>
                  <span className="text-amber-200/90">Potential dead notification</span>
                  {" — "}
                  {flag.title}: {flag.detail}
                </p>
              ))
            )}
          </CardContent>
        </Card>
      </div>
    </section>
  );
}
