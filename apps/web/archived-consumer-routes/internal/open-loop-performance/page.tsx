"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  getOpenLoopPerformanceSnapshot,
  resetOpenLoopPerformanceCounters,
  type OpenLoopPerformanceSnapshot,
} from "@/lib/open-loops/open-loop-performance";
import {
  isOpenLoopActivationDebugEnabled,
  setOpenLoopActivationDebugEnabled,
} from "@/lib/open-loops/open-loop-activation-debug";

const THRESHOLDS = {
  render: 10,
  detection: 2,
  storageReads: 20,
  storageWrites: 5,
};

function overThreshold(value: number, max: number): boolean {
  return value > max;
}

export default function OpenLoopPerformanceDebugPage() {
  const [snapshot, setSnapshot] = useState<OpenLoopPerformanceSnapshot | null>(null);
  const [debugOn, setDebugOn] = useState(false);

  const refresh = () => {
    setDebugOn(isOpenLoopActivationDebugEnabled());
    setSnapshot(getOpenLoopPerformanceSnapshot());
  };

  useEffect(() => {
    refresh();
    const id = window.setInterval(refresh, 1500);
    return () => clearInterval(id);
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Open loops</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Open loop performance watchdog
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Render and detection counters since load. Visit an entry page, then refresh. Threshold
              breaches highlight in amber.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        <div className="mt-6 flex flex-wrap gap-3">
          <Button
            type="button"
            variant="secondary"
            size="sm"
            onClick={() => {
              resetOpenLoopPerformanceCounters();
              refresh();
            }}
          >
            Reset counters
          </Button>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() => {
              setOpenLoopActivationDebugEnabled(!debugOn);
              setDebugOn(!debugOn);
            }}
          >
            {debugOn ? "Debug logs on" : "Debug logs off"}
          </Button>
          <Link href="/internal/open-loop-activation" className="text-sm text-zinc-500 hover:text-zinc-300">
            Activation audit →
          </Link>
        </div>

        {snapshot ? (
          <div className="mt-8 space-y-4">
            <Card className="border-white/10 bg-zinc-900/50">
              <CardHeader className="pb-2">
                <CardTitle className="text-base text-zinc-200">Totals</CardTitle>
              </CardHeader>
              <CardContent className="space-y-1 text-sm text-zinc-400">
                <p className={overThreshold(snapshot.unresolvedDetectionRuns, THRESHOLDS.detection) ? "text-amber-400" : ""}>
                  Unresolved detection runs: {snapshot.unresolvedDetectionRuns} (max {THRESHOLDS.detection})
                </p>
                <p className={overThreshold(snapshot.storageReads, THRESHOLDS.storageReads) ? "text-amber-400" : ""}>
                  Storage reads: {snapshot.storageReads}
                </p>
                <p className={overThreshold(snapshot.storageWrites, THRESHOLDS.storageWrites) ? "text-amber-400" : ""}>
                  Storage writes: {snapshot.storageWrites}
                </p>
                <p>Continuity build ms: {snapshot.continuityBuildMs.toFixed(1)}</p>
                <p>Deferred task ms: {snapshot.deferredTaskMs.toFixed(1)}</p>
              </CardContent>
            </Card>

            <Card className="border-white/10 bg-zinc-900/50">
              <CardHeader className="pb-2">
                <CardTitle className="text-base text-zinc-200">Render counts</CardTitle>
              </CardHeader>
              <CardContent className="space-y-1 text-sm text-zinc-400">
                {Object.keys(snapshot.renders).length === 0 ? (
                  <p>No renders recorded yet — open an entry page.</p>
                ) : (
                  Object.entries(snapshot.renders).map(([name, count]) => (
                    <p
                      key={name}
                      className={overThreshold(count, THRESHOLDS.render) ? "text-amber-400" : ""}
                    >
                      {name}: {count}
                    </p>
                  ))
                )}
              </CardContent>
            </Card>

            {snapshot.warnings.length > 0 ? (
              <Card className="border-amber-500/30 bg-amber-950/20">
                <CardHeader className="pb-2">
                  <CardTitle className="text-base text-amber-200">Warnings</CardTitle>
                </CardHeader>
                <CardContent className="space-y-1 text-sm text-amber-100/90">
                  {snapshot.warnings.map((warning) => (
                    <p key={warning}>{warning}</p>
                  ))}
                </CardContent>
              </Card>
            ) : null}

            <p className="text-xs text-zinc-600">Updated {snapshot.updatedAt}</p>
          </div>
        ) : null}
      </div>
    </div>
  );
}
