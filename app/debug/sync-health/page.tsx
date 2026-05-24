"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { CloudOff, RefreshCw, ShieldAlert } from "lucide-react";

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { buildLocalSyncModel } from "@/lib/sync/sync-model";
import {
  buildSyncHealthReport,
  hasPreRestoreBackup,
  restorePreRestoreSnapshot,
} from "@/lib/sync/sync-health";
import {
  inspectRemoteSyncHealth,
  syncArchiveIfSignedIn,
} from "@/lib/sync/client";
import {
  formatSimulationSummary,
  runAllSyncSimulations,
  runSyncSimulation,
  simulateMergeConflict,
} from "@/lib/sync/sync-simulator";
import { formatEntryDate } from "@/lib/utils";
import type { SyncHealthReport } from "@/types/sync-health";
import type { SyncSimulationResult, SyncSimulationScenario } from "@/types/sync-health";

function StatCard({
  label,
  value,
  hint,
}: {
  label: string;
  value: string;
  hint?: string;
}) {
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

const SCENARIOS: SyncSimulationScenario[] = [
  "corrupted_encrypted_sync_blob",
  "partial_restore",
  "stale_device_conflict",
  "offline_save_then_replay",
  "interrupted_audio_upload",
  "duplicate_entry_merge",
  "missing_audio_metadata",
  "restore_older_schema_version",
];

export default function SyncHealthDebugPage() {
  const [report, setReport] = useState<SyncHealthReport | null>(null);
  const [remoteEntryCount, setRemoteEntryCount] = useState<number | null>(null);
  const [corruptedRemote, setCorruptedRemote] = useState(false);
  const [simulations, setSimulations] = useState<SyncSimulationResult[]>([]);
  const [mergeDebug, setMergeDebug] = useState<string>("");
  const [busy, setBusy] = useState(false);
  const [actionLog, setActionLog] = useState<string | null>(null);

  const refresh = async () => {
    const next = await buildSyncHealthReport();
    setReport(next);

    try {
      const remote = await inspectRemoteSyncHealth();
      setRemoteEntryCount(remote.entryCount);
      setCorruptedRemote(remote.corrupted);
      if (remote.corrupted) {
        next.issues.push({
          type: "corrupted_remote_blob",
          detail: "Remote archive-core blob failed decryption or validation.",
        });
      }
      if (remote.entryCount !== null && remote.entryCount !== next.localEntryCount) {
        next.issues.push({
          type: "entry_count_mismatch",
          detail: `Local ${next.localEntryCount} vs remote ${remote.entryCount} entries.`,
        });
      }
      setReport({ ...next, remoteEntryCount: remote.entryCount, corruptedRemoteBlob: remote.corrupted });
    } catch {
      setRemoteEntryCount(null);
      setCorruptedRemote(false);
    }

    setSimulations(runAllSyncSimulations());
  };

  useEffect(() => {
    void refresh();
  }, []);

  const runScenario = (scenario: SyncSimulationScenario) => {
    const result = runSyncSimulation(scenario);
    setSimulations((current) => {
      const without = current.filter((row) => row.scenario !== scenario);
      return [...without, result];
    });
  };

  const runDryMerge = () => {
    const local = buildLocalSyncModel();
    const remote = {
      ...local,
      entries: local.entries.slice(0, Math.max(0, local.entries.length - 1)),
    };
    const result = simulateMergeConflict(local, remote);
    setMergeDebug(
      JSON.stringify(
        {
          localEntries: local.entries.length,
          remoteEntries: remote.entries.length,
          mergedEntries: result.model.entries.length,
          conflicts: result.conflicts,
        },
        null,
        2,
      ),
    );
  };

  const simSummary = formatSimulationSummary(simulations);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
              Encrypted backup
            </p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Sync health
            </h1>
            <p className="mt-2 text-sm text-zinc-400">
              Backup status, restore safety, and failure simulations.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={() => void refresh()}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        {!report ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">
              Loading…
            </CardContent>
          </Card>
        ) : (
          <div className="mt-6 space-y-6">
            <div className="grid gap-3 sm:grid-cols-2">
              <StatCard
                label="Last backup"
                value={report.lastBackupAt ? formatEntryDate(report.lastBackupAt) : "Never"}
              />
              <StatCard
                label="Last restore"
                value={report.lastRestoreAt ? formatEntryDate(report.lastRestoreAt) : "Never"}
              />
              <StatCard
                label="Local entries"
                value={String(report.localEntryCount)}
              />
              <StatCard
                label="Remote entries"
                value={remoteEntryCount === null ? "—" : String(remoteEntryCount)}
              />
              <StatCard
                label="Pending local changes"
                value={report.pendingLocalChanges ? "Yes" : "No"}
              />
              <StatCard
                label="Pre-restore backup"
                value={hasPreRestoreBackup() ? "Available" : "None"}
              />
              <StatCard
                label="Corrupted remote blob"
                value={corruptedRemote ? "Detected" : "No"}
              />
              <StatCard
                label="Audio backup"
                value={`${report.audioBackupStatus.localWithAudio} local / ${report.audioBackupStatus.remoteBackedUp} remote`}
                hint={
                  report.audioBackupStatus.recentFailures > 0
                    ? `${report.audioBackupStatus.recentFailures} recent upload failure(s)`
                    : undefined
                }
              />
            </div>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="flex items-center gap-2 text-sm font-normal text-zinc-200">
                  <ShieldAlert className="h-4 w-4 text-violet-300" />
                  Sync issues ({report.issues.length})
                </CardTitle>
              </CardHeader>
              <CardContent>
                {report.lastSyncError ? (
                  <p className="mb-3 text-sm text-red-300/90">{report.lastSyncError}</p>
                ) : null}
                {report.issues.length === 0 ? (
                  <p className="text-sm text-zinc-500">No sync issues detected.</p>
                ) : (
                  <ul className="space-y-2">
                    {report.issues.map((issue, index) => (
                      <li
                        key={`${issue.type}-${index}`}
                        className="rounded-xl bg-white/[0.03] px-3 py-2 text-sm"
                      >
                        <p className="font-medium text-zinc-200">{issue.type}</p>
                        <p className="mt-1 text-xs text-zinc-500">{issue.detail}</p>
                      </li>
                    ))}
                  </ul>
                )}
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="flex items-center gap-2 text-sm font-normal text-zinc-200">
                  <CloudOff className="h-4 w-4 text-violet-300" />
                  Failure simulations ({simSummary.passed}/{simulations.length} passed)
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex flex-wrap gap-2">
                  {SCENARIOS.map((scenario) => (
                    <Button
                      key={scenario}
                      type="button"
                      size="sm"
                      variant="secondary"
                      onClick={() => runScenario(scenario)}
                    >
                      {scenario.replaceAll("_", " ")}
                    </Button>
                  ))}
                  <Button type="button" size="sm" variant="ghost" onClick={() => setSimulations(runAllSyncSimulations())}>
                    Run all
                  </Button>
                </div>
                <ul className="space-y-2">
                  {simulations.map((row) => (
                    <li
                      key={row.scenario}
                      className="rounded-xl bg-white/[0.03] px-3 py-2 text-sm"
                    >
                      <p className={row.passed ? "text-emerald-300/90" : "text-red-300/90"}>
                        {row.scenario} — {row.passed ? "passed" : "failed"}
                      </p>
                      <p className="mt-1 text-xs text-zinc-500">{row.detail}</p>
                    </li>
                  ))}
                </ul>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-normal text-zinc-200">
                  Conflict simulation
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex flex-wrap gap-2">
                  <Button type="button" size="sm" variant="secondary" onClick={runDryMerge}>
                    Dry-run merge (trim remote)
                  </Button>
                  <Button
                    type="button"
                    size="sm"
                    variant="secondary"
                    disabled={busy}
                    onClick={() => {
                      setBusy(true);
                      void syncArchiveIfSignedIn()
                        .then((ok) => setActionLog(ok ? "Sync completed." : "Sync failed — local archive preserved."))
                        .finally(() => {
                          setBusy(false);
                          void refresh();
                        });
                    }}
                  >
                    Trigger sync
                  </Button>
                  <Button
                    type="button"
                    size="sm"
                    variant="ghost"
                    disabled={busy || !hasPreRestoreBackup()}
                    onClick={() => {
                      const restored = restorePreRestoreSnapshot();
                      setActionLog(
                        restored
                          ? "Pre-restore snapshot applied."
                          : "No pre-restore snapshot available.",
                      );
                      void refresh();
                    }}
                  >
                    Roll back to pre-restore
                  </Button>
                </div>
                {mergeDebug ? (
                  <pre className="overflow-x-auto whitespace-pre-wrap text-xs text-zinc-500">
                    {mergeDebug}
                  </pre>
                ) : null}
                {actionLog ? <p className="text-sm text-zinc-400">{actionLog}</p> : null}
              </CardContent>
            </Card>

            <div className="flex flex-wrap gap-3 text-sm">
              <Link href="/debug/stress" className="text-violet-300 hover:text-violet-200">
                Archive stress →
              </Link>
              <Link href="/debug/storage-health" className="text-zinc-500 hover:text-zinc-300">
                Storage health →
              </Link>
              <Link href="/account" className="text-zinc-500 hover:text-zinc-300">
                Account →
              </Link>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
