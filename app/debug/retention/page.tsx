"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { BarChart3, Bug, RefreshCw } from "lucide-react";

import { PatternSpecificityDebugPanel } from "@/components/debug/PatternSpecificityDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { buildAllEntryDebugSummaries } from "@/lib/pattern-detection";
import { buildSpecificityDebugReport } from "@/lib/patterns/specificity-debug";
import { buildRetentionDashboard, type RetentionDashboard } from "@/lib/retention-metrics";
import { getAllEntries } from "@/lib/storage";

function StatCard({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <Card>
      <CardHeader className="pb-1">
        <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
          {label}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-semibold tabular-nums text-white">{value}</p>
        {hint ? <p className="mt-1 text-xs text-zinc-600">{hint}</p> : null}
      </CardContent>
    </Card>
  );
}

export default function RetentionDebugPage() {
  const [data, setData] = useState<RetentionDashboard | null>(null);
  const [showPatternDebug, setShowPatternDebug] = useState(false);
  const [patternScores, setPatternScores] = useState<
    ReturnType<typeof buildAllEntryDebugSummaries>
  >([]);
  const [specificityReport, setSpecificityReport] = useState<
    ReturnType<typeof buildSpecificityDebugReport> | null
  >(null);

  const refresh = () => {
    setData(buildRetentionDashboard());
    const entries = getAllEntries();
    setPatternScores(buildAllEntryDebugSummaries(entries));
    setSpecificityReport(buildSpecificityDebugReport(entries, 12));
  };

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Launch validation</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Retention dashboard
            </h1>
            <p className="mt-2 text-sm text-zinc-400">
              Local-only indicators for first-user validation — nothing leaves this device.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        {!data ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">
              Loading…
            </CardContent>
          </Card>
        ) : (
          <div className="mt-6 space-y-6">
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
              <StatCard label="Total reflections" value={String(data.totalReflections)} />
              <StatCard label="Streak" value={`${data.streak} day${data.streak === 1 ? "" : "s"}`} />
              <StatCard label="Days active" value={String(data.daysActive)} />
              <StatCard
                label="Avg reflections / week"
                value={data.avgReflectionsPerWeek.toFixed(1)}
              />
              <StatCard
                label="Weekly return est."
                value={`${data.weeklyReturnEstimate}%`}
                hint="Weekly page opens vs weeks since first reflection"
              />
              <StatCard
                label="Feedback"
                value={`${data.feedback.up}↑ ${data.feedback.down}↓`}
                hint={`${data.feedback.total} total`}
              />
            </div>

            <Card>
              <CardHeader className="pb-2">
                <div className="flex items-center gap-2">
                  <BarChart3 className="h-4 w-4 text-violet-300" />
                  <CardTitle className="text-base">Feature usage counts</CardTitle>
                </div>
              </CardHeader>
              <CardContent>
                <dl className="grid gap-2 sm:grid-cols-2">
                  {Object.entries(data.featureUsage).map(([key, count]) => (
                    <div
                      key={key}
                      className="flex items-center justify-between rounded-xl bg-white/[0.03] px-3 py-2 text-sm"
                    >
                      <dt className="text-zinc-400">{key.replace(/([A-Z])/g, " $1")}</dt>
                      <dd className="font-medium tabular-nums text-white">{count}</dd>
                    </div>
                  ))}
                </dl>
                <p className="mt-4 text-xs text-zinc-600">
                  {data.totalLocalEvents} local events · {data.upgradeClicks} upgrade clicks
                </p>
              </CardContent>
            </Card>

            {(data.firstReflectionAt || data.lastReflectionAt) && (
              <Card>
                <CardHeader className="pb-2">
                  <CardTitle className="text-base">Activity span</CardTitle>
                </CardHeader>
                <CardContent className="text-sm text-zinc-400">
                  {data.firstReflectionAt ? (
                    <p>First active day: {data.firstReflectionAt}</p>
                  ) : null}
                  {data.lastReflectionAt ? (
                    <p className="mt-1">Last active day: {data.lastReflectionAt}</p>
                  ) : null}
                </CardContent>
              </Card>
            )}

            <Card className="border-amber-500/20">
              <CardHeader className="pb-2">
                <div className="flex items-center justify-between gap-3">
                  <div className="flex items-center gap-2">
                    <Bug className="h-4 w-4 text-amber-300" />
                    <CardTitle className="text-base">Pattern specificity debug</CardTitle>
                  </div>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => setShowPatternDebug((v) => !v)}
                  >
                    {showPatternDebug ? "Hide" : "Show"}
                  </Button>
                </div>
                <p className="text-xs text-zinc-500">
                  Scores exact phrase grounding, recurrence, cross-entry evidence, and
                  contradictions — &ldquo;This felt specific because…&rdquo;
                </p>
              </CardHeader>
              {showPatternDebug && specificityReport ? (
              <CardContent className="space-y-4">
                <PatternSpecificityDebugPanel
                  insights={specificityReport.insights}
                  title="Ranked insight specificity"
                  compact
                />
                <p className="text-xs text-zinc-600">
                  Per-entry legacy scores (pattern-detection module):
                </p>
                {patternScores.length === 0 ? (
                  <p className="text-sm text-zinc-500">No entries to score yet.</p>
                ) : (
                  patternScores
                    .sort((a, b) => b.score - a.score)
                    .map((row) => (
                      <div
                        key={row.entryId}
                        className="rounded-xl bg-white/[0.03] px-3 py-2 text-sm"
                      >
                        <div className="flex items-center justify-between gap-2">
                          <Link
                            href={`/entry/${row.entryId}`}
                            className="text-violet-300 hover:text-violet-200"
                          >
                            {new Date(row.date).toLocaleDateString()}
                          </Link>
                          <span className="font-medium tabular-nums text-white">
                            {row.score}/100
                          </span>
                        </div>
                        <p className="mt-1 text-xs text-zinc-500">{row.topReason}</p>
                      </div>
                    ))
                )}
              </CardContent>
            ) : null}
            </Card>

            <div className="flex flex-wrap gap-3 text-sm">
              <Link href="/debug/patterns" className="text-violet-300 hover:text-violet-200">
                Full pattern debug →
              </Link>
              <Link href="/launch" className="text-violet-300 hover:text-violet-200">
                Launch checklist →
              </Link>
              <Link href="/demo" className="text-zinc-500 hover:text-zinc-300">
                Demo mode →
              </Link>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
