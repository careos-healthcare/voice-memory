"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  auditOpenLoopActivation,
  type OpenLoopActivationAudit,
} from "@/lib/open-loops/open-loop-activation-audit";
import {
  isOpenLoopActivationDebugEnabled,
  setOpenLoopActivationDebugEnabled,
} from "@/lib/open-loops/open-loop-activation-debug";
import { getMemoryEligibleEntries } from "@/lib/storage";

const HAUNTED_FIXTURE =
  "I am haunted by the past, the present and the future. I'm scared.";

export default function OpenLoopActivationDebugPage() {
  const [rows, setRows] = useState<OpenLoopActivationAudit[]>([]);
  const [debugOn, setDebugOn] = useState(false);

  const refresh = () => {
    setDebugOn(isOpenLoopActivationDebugEnabled());
    const entries = getMemoryEligibleEntries().slice(0, 24);
    const fixtureAudit = auditOpenLoopActivation({
      id: "__fixture__",
      createdAt: new Date().toISOString(),
      transcript: HAUNTED_FIXTURE,
      reflection: {
        mood: "",
        emotionalIntensity: 0,
        recurringThemes: [],
        hiddenConcern: "",
        positiveSignal: "",
        recommendation: "",
      },
      durationSeconds: 0,
    });
    setRows([
      fixtureAudit,
      ...entries.map((entry) => auditOpenLoopActivation(entry)),
    ]);
  };

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-4xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Open loops</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Open loop activation audit
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Latest entries, unresolved signals, and why the keep-thread-open prompt would or
              would not show. Console logging is on in dev or when debug is enabled below.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        <div className="mt-6 flex flex-wrap items-center gap-3">
          <Button
            type="button"
            variant="secondary"
            size="sm"
            onClick={() => {
              setOpenLoopActivationDebugEnabled(!debugOn);
              setDebugOn(!debugOn);
            }}
          >
            {debugOn ? "Disable console debug" : "Enable console debug"}
          </Button>
          <Link href="/debug/open-loops-readout" className="text-sm text-zinc-500 hover:text-zinc-300">
            Open loops readout →
          </Link>
        </div>

        <div className="mt-8 space-y-4">
          {rows.map((row) => (
            <Card key={row.entryId} className="border-white/10 bg-zinc-900/50">
              <CardHeader className="pb-2">
                <CardTitle className="text-base font-medium text-zinc-200">
                  {row.entryId === "__fixture__" ? "Regression fixture" : row.entryId}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-2 text-sm text-zinc-400">
                <p>
                  <span className="text-zinc-500">Unresolved:</span>{" "}
                  {row.unresolvedDetected ? "yes" : "no"} (score {row.unresolvedScore})
                </p>
                <p>
                  <span className="text-zinc-500">Prompt would show:</span>{" "}
                  {row.showPrompt ? "yes" : "no"}
                </p>
                <p>
                  <span className="text-zinc-500">Suppression:</span>{" "}
                  {row.activationSuppressedReason ?? "none"}
                </p>
                <p>
                  <span className="text-zinc-500">Labels:</span>{" "}
                  {row.matchedLabels.length > 0 ? row.matchedLabels.join(", ") : "—"}
                </p>
                <p>
                  <span className="text-zinc-500">Anchors:</span>{" "}
                  {row.matchedSignals.length > 0
                    ? row.matchedSignals.map((s) => `"${s}"`).join("; ")
                    : "—"}
                </p>
                <p className="text-xs text-zinc-600">
                  loop={row.existingLoopFound ? "yes" : "no"} · dismissed=
                  {row.dismissedRecently ? "yes" : "no"} · freshWindow=
                  {row.freshEntryWindow ? "yes" : "no"} · freshQuiet=
                  {row.isFreshQuiet ? "yes" : "no"} · revisit={row.revisitMode ? "yes" : "no"}
                </p>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </div>
  );
}
