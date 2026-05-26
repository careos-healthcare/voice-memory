"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Database, RefreshCw, Wrench } from "lucide-react";

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  clearRecoveryDrafts,
  listRecoveryDrafts,
  recoverPendingDrafts,
} from "@/lib/reliability/draft-recovery";
import {
  buildStorageHealthReport,
  clearBrokenAudioReferences,
  clearBrokenPhotoReferences,
  repairEntryIntegrity,
} from "@/lib/reliability/integrity";
import {
  buildHomepageCarryoverLine,
  readEmotionalContinuity,
} from "@/lib/sync/cross-device-continuity";
import { readDeviceId } from "@/lib/sync/device-id";
import { restoreFromBackup } from "@/lib/reliability/safe-local-storage";
import { CURRENT_STORAGE_VERSION } from "@/lib/reliability/storage-version";
import type { RepairResult, StorageHealthReport } from "@/types/storage-reliability";

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

function RepairLog({ result }: { result: RepairResult | null }) {
  if (!result) return null;

  return (
    <Card className="mt-4 border-emerald-900/40">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-emerald-200/90">
          Repair complete — {result.repaired} change(s)
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.details.length === 0 ? (
          <p className="text-sm text-zinc-500">Nothing needed changing.</p>
        ) : (
          <ul className="space-y-1 text-xs text-zinc-400">
            {result.details.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

export default function StorageHealthDebugPage() {
  const [report, setReport] = useState<StorageHealthReport | null>(null);
  const [draftCount, setDraftCount] = useState(0);
  const [repairResult, setRepairResult] = useState<RepairResult | null>(null);
  const [busy, setBusy] = useState(false);
  const [continuityDebug, setContinuityDebug] = useState<string>("");

  const refresh = async () => {
    setReport(await buildStorageHealthReport());
    setDraftCount(listRecoveryDrafts().length);
    const record = readEmotionalContinuity();
    const carryover = buildHomepageCarryoverLine({ requirePending: false });
    setContinuityDebug(
      JSON.stringify(
        {
          deviceId: readDeviceId(),
          record,
          previewCarryover: carryover,
        },
        null,
        2,
      ),
    );
  };

  useEffect(() => {
    void refresh();
  }, []);

  const runRepair = async (action: () => Promise<RepairResult>) => {
    setBusy(true);
    setRepairResult(null);
    try {
      const result = await action();
      setRepairResult(result);
      await refresh();
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
              Local storage
            </p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Storage health
            </h1>
            <p className="mt-2 text-sm text-zinc-400">
              Entry integrity, audio and photo references, and migration version — all on
              this device.
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
              <StatCard label="Entries" value={String(report.entriesCount)} />
              <StatCard label="Audio files" value={String(report.audioCount)} />
              <StatCard label="Photo anchors" value={String(report.photoCount)} />
              <StatCard
                label="Migration version"
                value={`${report.storageVersion} / ${CURRENT_STORAGE_VERSION}`}
              />
              <StatCard label="Recovery drafts" value={String(draftCount)} />
              <StatCard
                label="Broken audio refs"
                value={String(report.brokenAudioReferences)}
              />
              <StatCard
                label="Broken photo refs"
                value={String(report.brokenPhotoReferences)}
              />
              <StatCard
                label="Photo restore status"
                value={report.photoRestoreReady ? "Ready" : "Needs review"}
                hint={
                  report.orphanPhotoBlobs > 0
                    ? `${report.orphanPhotoBlobs} orphan blob(s)`
                    : undefined
                }
              />
              <StatCard
                label="Duplicate IDs"
                value={String(report.duplicateIds)}
              />
              <StatCard
                label="Malformed reflections"
                value={String(report.malformedReflections)}
              />
              <StatCard
                label="Missing timestamps"
                value={String(report.missingTimestamps)}
              />
            </div>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="flex items-center gap-2 text-sm font-normal text-zinc-200">
                  <Database className="h-4 w-4 text-violet-300" />
                  Integrity issues ({report.issues.length})
                </CardTitle>
              </CardHeader>
              <CardContent>
                {report.issues.length === 0 ? (
                  <p className="text-sm text-zinc-500">No issues detected.</p>
                ) : (
                  <ul className="space-y-2">
                    {report.issues.map((issue, index) => (
                      <li
                        key={`${issue.type}-${issue.entryId ?? index}`}
                        className="rounded-xl bg-white/[0.03] px-3 py-2 text-sm"
                      >
                        <p className="font-medium text-zinc-200">{issue.type}</p>
                        <p className="mt-1 text-xs text-zinc-500">{issue.detail}</p>
                        {issue.entryId ? (
                          <Link
                            href={`/entry/${issue.entryId}`}
                            className="mt-1 inline-block text-xs text-violet-300 hover:text-violet-200"
                          >
                            View entry →
                          </Link>
                        ) : null}
                      </li>
                    ))}
                  </ul>
                )}
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-normal text-zinc-200">
                  Cross-device archive sync
                </CardTitle>
              </CardHeader>
              <CardContent>
                <pre className="overflow-x-auto whitespace-pre-wrap text-xs text-zinc-500">
                  {continuityDebug || "No continuity state."}
                </pre>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="flex items-center gap-2 text-sm font-normal text-zinc-200">
                  <Wrench className="h-4 w-4 text-violet-300" />
                  Repair actions
                </CardTitle>
              </CardHeader>
              <CardContent className="flex flex-wrap gap-2">
                <Button
                  type="button"
                  size="sm"
                  disabled={busy}
                  onClick={() => void runRepair(repairEntryIntegrity)}
                >
                  Repair entries
                </Button>
                <Button
                  type="button"
                  size="sm"
                  variant="secondary"
                  disabled={busy}
                  onClick={() => void runRepair(clearBrokenPhotoReferences)}
                >
                  Clear broken photo refs
                </Button>
                <Button
                  type="button"
                  size="sm"
                  variant="secondary"
                  disabled={busy}
                  onClick={() => void runRepair(clearBrokenAudioReferences)}
                >
                  Clear broken audio refs
                </Button>
                <Button
                  type="button"
                  size="sm"
                  variant="secondary"
                  disabled={busy || draftCount === 0}
                  onClick={() => {
                    setBusy(true);
                    setRepairResult(null);
                    const { recovered } = recoverPendingDrafts();
                    setRepairResult({
                      repaired: recovered,
                      details:
                        recovered > 0
                          ? [`Recovered ${recovered} draft(s) into entries`]
                          : [],
                    });
                    void refresh().finally(() => setBusy(false));
                  }}
                >
                  Recover drafts
                </Button>
                <Button
                  type="button"
                  size="sm"
                  variant="ghost"
                  disabled={busy}
                  onClick={() => {
                    const restored = restoreFromBackup("voicememory_entries");
                    setRepairResult({
                      repaired: restored ? 1 : 0,
                      details: restored
                        ? ["Restored entries from local backup copy"]
                        : ["No backup copy available"],
                    });
                    void refresh();
                  }}
                >
                  Restore entries backup
                </Button>
                <Button
                  type="button"
                  size="sm"
                  variant="ghost"
                  disabled={busy || draftCount === 0}
                  onClick={() => {
                    const cleared = clearRecoveryDrafts();
                    setRepairResult({
                      repaired: cleared,
                      details: [`Cleared ${cleared} recovery draft(s)`],
                    });
                    void refresh();
                  }}
                >
                  Clear recovery drafts
                </Button>
              </CardContent>
            </Card>

            <RepairLog result={repairResult} />

            <div className="flex flex-wrap gap-3 text-sm">
              <Link href="/debug/stress" className="text-violet-300 hover:text-violet-200">
                Archive stress →
              </Link>
              <Link href="/debug/retention" className="text-violet-300 hover:text-violet-200">
                Retention dashboard →
              </Link>
              <Link href="/debug/sync-health" className="text-violet-300 hover:text-violet-200">
                Sync health →
              </Link>
              <Link href="/archive" className="text-violet-300 hover:text-violet-200">
                Archive permanence →
              </Link>
              <Link href="/settings" className="text-zinc-500 hover:text-zinc-300">
                Settings →
              </Link>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
