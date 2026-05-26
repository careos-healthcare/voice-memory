"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ResurfacingVarietyPanel } from "@/components/debug/ResurfacingVarietyPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { buildResurfacingVarietyReport } from "@/lib/resurfacing/resurfacing-variety-report";
import type { ResurfacingVarietyReport } from "@/types/resurfacing-variety";

export default function ResurfacingVarietyDebugPage() {
  const [report, setReport] = useState<ResurfacingVarietyReport | null>(null);

  const refresh = () => {
    setReport(buildResurfacingVarietyReport());
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
              Resurfacing variety
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Return-mode distribution and template fatigue — whether resurfacing feels
              situational or repeats the same emotional cadence.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        <p className="mt-4 text-xs text-zinc-600">{report?.scopeNote}</p>

        <div className="mt-8">
          {report ? <ResurfacingVarietyPanel report={report} /> : null}
        </div>

        <p className="mt-10 text-xs text-zinc-600">
          <Link href="/debug/behavior-truth" className="text-zinc-500 hover:text-zinc-300">
            Behavioral truth
          </Link>
          {" · "}
          <Link
            href="/debug/reflection-friction"
            className="text-zinc-500 hover:text-zinc-300"
          >
            Reflection friction
          </Link>
        </p>
      </div>
    </div>
  );
}
