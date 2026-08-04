"use client";

import Link from "next/link";
import {
  ArrowDownRight,
  ArrowUpRight,
  Ghost,
  History,
  RefreshCw,
  Sparkles,
  TrendingDown,
  TrendingUp,
} from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { surfaceHeadline } from "@/lib/patterns/continuity-engine";
import type {
  ContinuityItem,
  ContinuityReport,
  ContinuitySurfaceLabel,
  IdentityDriftInsight,
  NarrativeArc,
  PeriodSummary,
} from "@/types/continuity";

interface LongitudinalContinuityCardProps {
  report: ContinuityReport;
  title?: string;
  subtitle?: string;
  emptyLabel?: string;
  maxItems?: number;
  highlightEntryId?: string;
  hideWhenEmpty?: boolean;
  showSummaries?: boolean;
  showArcs?: boolean;
  showIdentity?: boolean;
  className?: string;
}

function surfaceIcon(surface: ContinuitySurfaceLabel) {
  switch (surface) {
    case "calmer":
      return TrendingDown;
    case "more_intense":
      return TrendingUp;
    case "disappeared":
      return Ghost;
    case "reappeared":
      return RefreshCw;
    case "emerged":
      return Sparkles;
    case "changed_over_time":
      return History;
  }
}

function surfaceAccent(surface: ContinuitySurfaceLabel): string {
  switch (surface) {
    case "calmer":
      return "text-emerald-300";
    case "more_intense":
      return "text-amber-300";
    case "disappeared":
      return "text-zinc-400";
    case "reappeared":
      return "text-sky-300";
    case "emerged":
      return "text-violet-300";
    case "changed_over_time":
      return "text-fuchsia-300";
  }
}

function ContinuityItemBlock({
  item,
  highlightEntryId,
}: {
  item: ContinuityItem;
  highlightEntryId?: string;
}) {
  const Icon = surfaceIcon(item.surface);
  const accent = surfaceAccent(item.surface);

  return (
    <div className="rounded-xl border border-white/10 bg-black/20 p-4">
      <div className="flex items-start gap-2">
        <Icon className={`mt-0.5 h-4 w-4 shrink-0 ${accent}`} />
        <div className="min-w-0 flex-1">
          <p className="text-[10px] uppercase tracking-wider text-zinc-500">
            {surfaceHeadline(item.surface)}
          </p>
          <p className="mt-1 text-sm font-medium leading-relaxed text-white">{item.title}</p>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">{item.detail}</p>
        </div>
      </div>

      {item.evidence.length > 0 ? (
        <div className="mt-3 space-y-2">
          {item.evidence.slice(0, 2).map((ev) => (
            <div
              key={`${item.id}-${ev.entryId}`}
              className={`rounded-lg border px-3 py-2 ${
                highlightEntryId === ev.entryId
                  ? "border-violet-400/30 bg-violet-500/10"
                  : "border-white/5 bg-white/[0.02]"
              }`}
            >
              <Link
                href={`/entry/${ev.entryId}`}
                className="text-xs text-violet-300 hover:text-violet-200"
              >
                {ev.dateLabel}
              </Link>
              <p className="mt-1 text-xs italic leading-relaxed text-zinc-400">
                &ldquo;{ev.phrase.slice(0, 140)}&rdquo;
              </p>
            </div>
          ))}
        </div>
      ) : null}
    </div>
  );
}

function ArcBlock({ arc }: { arc: NarrativeArc }) {
  return (
    <div className="rounded-xl border border-white/10 bg-black/20 p-4">
      <Badge variant="secondary" className="mb-2 text-[10px] capitalize">
        {arc.kind.replace(/_/g, " ")}
      </Badge>
      <p className="text-sm font-medium text-white">{arc.title}</p>
      <p className="mt-2 text-sm text-zinc-400">{arc.detail}</p>
    </div>
  );
}

function SummaryBlock({ summary }: { summary: PeriodSummary }) {
  return (
    <div className="rounded-xl border border-white/10 bg-black/20 p-4">
      <p className="text-[10px] uppercase tracking-wider text-zinc-500">
        {summary.period === "month" ? "Monthly" : "Quarter"} · {summary.periodLabel}
      </p>
      <p className="mt-1 text-sm font-medium text-white">{summary.title}</p>
      <ul className="mt-2 space-y-1">
        {summary.lines.map((line) => (
          <li key={line} className="text-sm text-zinc-400">
            {line}
          </li>
        ))}
      </ul>
    </div>
  );
}

function IdentityBlock({ insight }: { insight: IdentityDriftInsight }) {
  return (
    <div className="rounded-xl border border-white/10 bg-black/20 p-4">
      <div className="flex items-center gap-2">
        {insight.direction === "more_certain" || insight.direction === "more_direct" ? (
          <ArrowUpRight className="h-4 w-4 text-emerald-300" />
        ) : insight.direction === "more_hopeful" ? (
          <Sparkles className="h-4 w-4 text-violet-300" />
        ) : (
          <ArrowDownRight className="h-4 w-4 text-zinc-400" />
        )}
        <p className="text-sm font-medium text-white">{insight.title}</p>
      </div>
      <p className="mt-2 text-sm text-zinc-400">{insight.detail}</p>
    </div>
  );
}

export function LongitudinalContinuityCard({
  report,
  title = "Longitudinal continuity",
  subtitle = "How themes, language, and intensity shifted across your archive",
  emptyLabel = "Continuity patterns appear as you save more voice moments.",
  maxItems = 8,
  highlightEntryId,
  hideWhenEmpty = false,
  showSummaries = true,
  showArcs = true,
  showIdentity = true,
  className,
}: LongitudinalContinuityCardProps) {
  const items = report.items.slice(0, maxItems);
  const hasContent =
    items.length > 0 ||
    (showArcs && report.narrativeArcs.length > 0) ||
    (showSummaries && report.periodSummaries.length > 0) ||
    (showIdentity && report.identityDrift.length > 0);

  if (!hasContent) {
    if (hideWhenEmpty) return null;
    return (
      <Card className={`border-dashed border-white/10 ${className ?? ""}`}>
        <CardHeader className="pb-2">
          <div className="flex items-center gap-2">
            <History className="h-4 w-4 text-fuchsia-300" />
            <CardTitle className="text-base">{title}</CardTitle>
          </div>
          {subtitle ? <p className="text-xs text-zinc-500">{subtitle}</p> : null}
        </CardHeader>
        <CardContent>
          <p className="text-sm text-zinc-500">{emptyLabel}</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className={`border-fuchsia-500/20 bg-fuchsia-950/10 ${className ?? ""}`}>
      <CardHeader className="pb-2">
        <div className="flex items-center gap-2">
          <History className="h-4 w-4 text-fuchsia-300" />
          <CardTitle className="text-base">{title}</CardTitle>
        </div>
        {subtitle ? <p className="text-xs text-zinc-500">{subtitle}</p> : null}
      </CardHeader>
      <CardContent className="space-y-6">
        {items.length > 0 ? (
          <div className="space-y-3">
            {items.map((item) => (
              <ContinuityItemBlock
                key={item.id}
                item={item}
                highlightEntryId={highlightEntryId}
              />
            ))}
          </div>
        ) : null}

        {showArcs && report.narrativeArcs.length > 0 ? (
          <div className="space-y-3">
            <p className="text-xs uppercase tracking-wider text-zinc-500">Narrative arcs</p>
            {report.narrativeArcs.slice(0, 4).map((arc) => (
              <ArcBlock key={arc.id} arc={arc} />
            ))}
          </div>
        ) : null}

        {showIdentity && report.identityDrift.length > 0 ? (
          <div className="space-y-3">
            <p className="text-xs uppercase tracking-wider text-zinc-500">Identity shifts</p>
            {report.identityDrift.slice(0, 3).map((insight) => (
              <IdentityBlock key={insight.id} insight={insight} />
            ))}
          </div>
        ) : null}

        {showSummaries && report.periodSummaries.length > 0 ? (
          <div className="space-y-3">
            <p className="text-xs uppercase tracking-wider text-zinc-500">
              Evolution summaries
            </p>
            {report.periodSummaries.slice(0, 3).map((summary) => (
              <SummaryBlock key={summary.id} summary={summary} />
            ))}
          </div>
        ) : null}
      </CardContent>
    </Card>
  );
}

export function ContinuityChangeMomentsCard({
  report,
  title = "Change moments",
  maxItems = 4,
  highlightEntryId,
  hideWhenEmpty = false,
}: {
  report: ContinuityReport;
  title?: string;
  maxItems?: number;
  highlightEntryId?: string;
  hideWhenEmpty?: boolean;
}) {
  const items = [...report.changeMoments, ...report.beforeAfter]
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, maxItems);

  if (items.length === 0) {
    if (hideWhenEmpty) return null;
    return null;
  }

  return (
    <Card className="border-amber-500/20 bg-amber-950/10">
      <CardHeader className="pb-2">
        <CardTitle className="text-base">{title}</CardTitle>
        <p className="text-xs text-zinc-500">Sudden shifts and before/after comparisons</p>
      </CardHeader>
      <CardContent className="space-y-3">
        {items.map((item) => (
          <ContinuityItemBlock key={item.id} item={item} highlightEntryId={highlightEntryId} />
        ))}
      </CardContent>
    </Card>
  );
}
