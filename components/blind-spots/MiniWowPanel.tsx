"use client";

import Link from "next/link";

import { Card, CardContent } from "@/components/ui/card";
import { MINI_WOW_COPY } from "@/lib/blind-spots/mini-wow-copy";
import { buildMiniWowReport } from "@/lib/blind-spots/mini-wow";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { MiniWowReport } from "@/types/mini-wow";
import { useEffect, useMemo, useState } from "react";

interface MiniWowPanelProps {
  className?: string;
  /** When set (e.g. post-save), includes the entry just saved. */
  entriesOverride?: import("@/types/journal").JournalEntry[];
  /** Compact layout for recorder complete state. */
  compact?: boolean;
}

export function MiniWowPanel({
  className,
  entriesOverride,
  compact = false,
}: MiniWowPanelProps) {
  const entries = useMemo(
    () => entriesOverride ?? getMemoryEligibleEntries(),
    [entriesOverride],
  );
  const [report, setReport] = useState<MiniWowReport | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setReport(buildMiniWowReport(entries));
    });
    return () => cancelAnimationFrame(id);
  }, [entries]);

  if (!report?.showPanel) return null;

  const padding = compact ? "p-4" : "p-5";

  return (
    <Card
      className={`border-dashed border-violet-400/20 bg-violet-950/10 ${className ?? ""}`}
    >
      <CardContent className={`space-y-3 ${padding}`}>
        <p className="text-xs font-medium text-violet-200/90">{report.panelTitle}</p>
        {report.tier !== "first" ? (
          <p className="text-[11px] text-zinc-600">{report.progressLabel}</p>
        ) : null}
        {report.title ? (
          <div>
            <p className="text-sm font-medium text-violet-100">{report.title}</p>
            {report.confidenceLabel ? (
              <p className="mt-0.5 text-[10px] uppercase tracking-wide text-zinc-500">
                {report.confidenceLabel}
              </p>
            ) : null}
          </div>
        ) : null}
        <p className="text-sm leading-relaxed text-zinc-400">{report.body}</p>
        {report.evidenceQuotes.length > 0 ? (
          <ul className="space-y-2 border-t border-white/5 pt-3">
            {report.evidenceQuotes.map((q) => (
              <li key={q.entryId} className="text-xs leading-relaxed text-zinc-500">
                <span className="text-zinc-600">{q.dateLabel}</span>
                <span className="mt-0.5 block text-zinc-400">“{q.quote}”</span>
              </li>
            ))}
          </ul>
        ) : null}
        <p className="text-xs text-zinc-600">{report.disclaimer}</p>
      </CardContent>
    </Card>
  );
}

interface MiniWowUnlockedLinkProps {
  className?: string;
  entriesOverride?: import("@/types/journal").JournalEntry[];
}

/** Shown at 5+ reflections when mini-wow steps aside for full blind spot review. */
export function MiniWowUnlockedLink({ className, entriesOverride }: MiniWowUnlockedLinkProps) {
  const entries = useMemo(
    () => entriesOverride ?? getMemoryEligibleEntries(),
    [entriesOverride],
  );
  const report = useMemo(() => buildMiniWowReport(entries), [entries]);

  if (report.tier !== "unlocked") return null;

  return (
    <Card className={`border-violet-400/25 bg-violet-950/15 ${className ?? ""}`}>
      <CardContent className="space-y-3 p-5">
        <p className="text-xs font-medium text-violet-200/90">{report.panelTitle}</p>
        <p className="text-xs text-zinc-500">{report.progressLabel}</p>
        <p className="text-sm font-medium text-violet-100">{MINI_WOW_COPY.unlockedTitle}</p>
        <p className="text-sm leading-relaxed text-zinc-400">{MINI_WOW_COPY.unlockedBody}</p>
        <Link
          href="/blind-spots"
          className="inline-flex text-sm font-medium text-violet-300 hover:text-violet-200"
        >
          {MINI_WOW_COPY.unlockedAction} →
        </Link>
      </CardContent>
    </Card>
  );
}
