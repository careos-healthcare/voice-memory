"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { AlertTriangle, Play, RefreshCw } from "lucide-react";

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  formatStressReportSummary,
  readLastStressTestReport,
  runAllArchiveStressTests,
  runArchiveStressTest,
  saveStressTestReport,
  STRESS_TEST_SEED,
} from "@/lib/reliability/stress-tests";
import { formatEntryDate } from "@/lib/utils";
import type { ArchiveStressScenario, StressTestRunReport } from "@/types/archive-stress";

const SCENARIOS: ArchiveStressScenario[] = [
  "entry_save_loop_1000",
  "interrupted_sync_mid_upload",
  "corrupted_encrypted_payload",
  "duplicate_device_sync_race",
  "audio_blob_mismatch",
  "offline_replay_after_7_days",
  "partial_indexeddb_failure",
  "localstorage_quota_exhaustion",
  "restore_rollback_failure",
  "stale_device_overwrite_attempt",
];

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

export default function ArchiveStressDebugPage() {
  const [report, setReport] = useState<StressTestRunReport | null>(null);

  const refresh = () => {
    setReport(readLastStressTestReport());
  };

  useEffect(() => {
    refresh();
  }, []);

  const runAll = () => {
    const next = runAllArchiveStressTests();
    saveStressTestReport(next);
    setReport(next);
  };

  const runOne = (scenario: ArchiveStressScenario) => {
    const result = runArchiveStressTest(scenario);
    const base = readLastStressTestReport();
    const results = base?.results.filter((row) => row.scenario !== scenario) ?? [];
    const next: StressTestRunReport = {
      runAt: new Date().toISOString(),
      seed: STRESS_TEST_SEED,
      results: [...results, result],
      passed: 0,
      failed: 0,
      allPassed: false,
    };
    next.passed = next.results.filter((row) => row.passed).length;
    next.failed = next.results.length - next.passed;
    next.allPassed = next.failed === 0;
    saveStressTestReport(next);
    setReport(next);
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
              Archive reliability
            </p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Stress tests
            </h1>
            <p className="mt-2 text-sm text-zinc-400">
              Deterministic failure simulations — fails loudly here, not in production.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        <div className="mt-6 space-y-6">
          <div className="grid gap-3 sm:grid-cols-2">
            <StatCard
              label="Last run"
              value={report?.runAt ? formatEntryDate(report.runAt) : "Never"}
              hint={report ? formatStressReportSummary(report) : undefined}
            />
            <StatCard
              label="Overall"
              value={report ? (report.allPassed ? "Pass" : "Fail") : "—"}
              hint={`Seed ${STRESS_TEST_SEED}`}
            />
            <StatCard
              label="Passed"
              value={report ? String(report.passed) : "—"}
            />
            <StatCard
              label="Failed"
              value={report ? String(report.failed) : "—"}
            />
          </div>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="flex items-center gap-2 text-sm font-normal text-zinc-200">
                <Play className="h-4 w-4 text-violet-300" />
                Run simulations
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex flex-wrap gap-2">
                <Button type="button" size="sm" variant="secondary" onClick={runAll}>
                  Run all
                </Button>
                {SCENARIOS.map((scenario) => (
                  <Button
                    key={scenario}
                    type="button"
                    size="sm"
                    variant="ghost"
                    onClick={() => runOne(scenario)}
                  >
                    {scenario.replaceAll("_", " ")}
                  </Button>
                ))}
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="flex items-center gap-2 text-sm font-normal text-zinc-200">
                <AlertTriangle className="h-4 w-4 text-violet-300" />
                Results
              </CardTitle>
            </CardHeader>
            <CardContent>
              {!report || report.results.length === 0 ? (
                <p className="text-sm text-zinc-500">No stress test run yet.</p>
              ) : (
                <ul className="space-y-3">
                  {report.results.map((row) => (
                    <li
                      key={row.scenario}
                      className="rounded-xl bg-white/[0.03] px-3 py-3 text-sm"
                    >
                      <p className={row.passed ? "text-emerald-300/90" : "text-red-300/90"}>
                        {row.scenario} — {row.passed ? "passed" : "FAILED"}
                        <span className="ml-2 text-xs text-zinc-600">{row.durationMs}ms</span>
                      </p>
                      <p className="mt-1 text-xs text-zinc-500">{row.detail}</p>
                      <p className="mt-1 text-xs text-zinc-400">
                        Recovery path: {row.recoveryPath}
                      </p>
                      {row.failedAssertions.length > 0 ? (
                        <ul className="mt-2 space-y-1">
                          {row.failedAssertions.map((assertion) => (
                            <li key={assertion} className="text-xs text-red-300/80">
                              {assertion}
                            </li>
                          ))}
                        </ul>
                      ) : null}
                      {row.corruptedPayloadPreview ? (
                        <pre className="mt-2 overflow-x-auto whitespace-pre-wrap rounded-lg bg-black/30 p-2 text-xs text-amber-200/80">
                          corrupted payload: {row.corruptedPayloadPreview}
                        </pre>
                      ) : null}
                      {row.rollbackPreview ? (
                        <pre className="mt-2 overflow-x-auto whitespace-pre-wrap rounded-lg bg-black/30 p-2 text-xs text-sky-200/80">
                          rollback preview: {row.rollbackPreview}
                        </pre>
                      ) : null}
                    </li>
                  ))}
                </ul>
              )}
            </CardContent>
          </Card>

          <div className="flex flex-wrap gap-3 text-sm">
            <Link href="/debug/sync-health" className="text-violet-300 hover:text-violet-200">
              Sync health →
            </Link>
            <Link href="/debug/storage-health" className="text-zinc-500 hover:text-zinc-300">
              Storage health →
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
