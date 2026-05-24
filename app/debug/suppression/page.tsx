"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw, VolumeX } from "lucide-react";

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { buildSuppressionReviewReport } from "@/lib/debug/suppression-review";
import { getAllEntries } from "@/lib/storage";
import type { SuppressionReviewReport } from "@/types/suppression-review";

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <Card>
      <CardHeader className="pb-1">
        <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
          {label}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-semibold tabular-nums text-white">{value}</p>
      </CardContent>
    </Card>
  );
}

export default function SuppressionDebugPage() {
  const [report, setReport] = useState<SuppressionReviewReport | null>(null);
  const [showSuppressedOnly, setShowSuppressedOnly] = useState(true);

  const refresh = () => {
    setReport(buildSuppressionReviewReport(getAllEntries()));
  };

  useEffect(() => {
    refresh();
  }, []);

  const visibleItems =
    report?.items.filter((item) => !showSuppressedOnly || item.suppressed) ?? [];

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
              Emotional safety
            </p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Suppression review
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Candidates that stayed quiet — weak contrast, generic wording, recent repeats, and
              other false-positive signals.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
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
        ) : !report.hasData ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">
              Add reflections to review suppression candidates.
            </CardContent>
          </Card>
        ) : (
          <div className="mt-6 space-y-6">
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <StatCard label="Candidates" value={String(report.totalCandidates)} />
              <StatCard label="Suppressed" value={String(report.suppressedCount)} />
              <StatCard label="Would surface" value={String(report.surfacedCount)} />
              <StatCard
                label="Top reason"
                value={
                  Object.entries(report.byReason).sort((a, b) => b[1] - a[1])[0]?.[0]?.replaceAll(
                    "_",
                    " ",
                  ) ?? "—"
                }
              />
            </div>

            <div className="flex items-center gap-3">
              <label className="flex items-center gap-2 text-sm text-zinc-400">
                <input
                  type="checkbox"
                  checked={showSuppressedOnly}
                  onChange={(event) => setShowSuppressedOnly(event.target.checked)}
                />
                Suppressed only
              </label>
            </div>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="flex items-center gap-2 text-sm font-normal text-zinc-200">
                  <VolumeX className="h-4 w-4 text-violet-300" />
                  Notes ({visibleItems.length})
                </CardTitle>
              </CardHeader>
              <CardContent>
                {visibleItems.length === 0 ? (
                  <p className="text-sm text-zinc-500">No matching candidates.</p>
                ) : (
                  <ul className="space-y-3">
                    {visibleItems.map((item) => (
                      <li
                        key={`${item.id}-${item.text}`}
                        className="rounded-xl bg-white/[0.03] px-3 py-3 text-sm"
                      >
                        <div className="flex flex-wrap items-center gap-2">
                          <span
                            className={
                              item.suppressed
                                ? "text-amber-200/90"
                                : "text-emerald-300/90"
                            }
                          >
                            {item.suppressed ? "suppressed" : "would surface"}
                          </span>
                          <span className="text-xs text-zinc-600">{item.sourceModule}</span>
                          {item.hierarchyScore !== undefined ? (
                            <span className="text-xs text-zinc-600">
                              score {item.hierarchyScore}
                            </span>
                          ) : null}
                        </div>
                        <p className="mt-2 text-zinc-200">{item.candidateText}</p>
                        {item.reasons.length > 0 ? (
                          <p className="mt-2 text-xs text-zinc-500">
                            Reason: {item.reasons.join(", ").replaceAll("_", " ")}
                          </p>
                        ) : null}
                        {item.missingEvidence.length > 0 ? (
                          <p className="mt-1 text-xs text-zinc-600">
                            Missing: {item.missingEvidence.join(" · ")}
                          </p>
                        ) : null}
                      </li>
                    ))}
                  </ul>
                )}
              </CardContent>
            </Card>

            <div className="flex flex-wrap gap-3 text-sm">
              <Link href="/debug/callbacks" className="text-violet-300 hover:text-violet-200">
                Callback survival →
              </Link>
              <Link href="/debug/patterns" className="text-violet-300 hover:text-violet-200">
                Pattern specificity →
              </Link>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
