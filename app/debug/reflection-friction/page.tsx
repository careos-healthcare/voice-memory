"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ReflectionFrictionPanel } from "@/components/debug/ReflectionFrictionPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { buildReflectionFrictionReport } from "@/lib/reflection/reflection-friction-report";
import {
  disableQuickReflectionMode,
  enableQuickReflectionMode,
  isQuickReflectionEnabled,
} from "@/lib/reflection/quick-reflection";
import type { ReflectionFrictionReport } from "@/types/reflection-friction";

export default function ReflectionFrictionDebugPage() {
  const [report, setReport] = useState<ReflectionFrictionReport | null>(null);

  const refresh = () => {
    setReport(buildReflectionFrictionReport());
  };

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen-mobile bg-zinc-950 pb-safe">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Debug</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Reflection friction
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Local funnel from resurfacing to recording — where the repeat reflection loop
              stalls.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        <div className="mt-8">
          {report ? <ReflectionFrictionPanel report={report} /> : null}
        </div>

        <p className="mt-8 text-sm text-zinc-500">
          Quick reflection mode:{" "}
          {isQuickReflectionEnabled() ? "on" : "off"}.{" "}
          <button
            type="button"
            className="text-violet-300/90 hover:text-violet-200"
            onClick={() => {
              if (isQuickReflectionEnabled()) disableQuickReflectionMode();
              else enableQuickReflectionMode();
              refresh();
            }}
          >
            Toggle
          </button>
        </p>

        <p className="mt-10 text-xs text-zinc-600">
          <Link href="/debug/behavior-truth" className="text-zinc-500 hover:text-zinc-300">
            Behavioral truth
          </Link>
        </p>
      </div>
    </div>
  );
}
