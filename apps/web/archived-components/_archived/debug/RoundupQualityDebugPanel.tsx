"use client";

import { useMemo, useState } from "react";
import Link from "next/link";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  getRoundupReviewLabels,
  toggleRoundupReviewLabel,
} from "@/lib/debug/roundup-review-labels";
import {
  ROUNDUP_QUALITY_REASON_LABELS,
  ROUNDUP_REVIEW_LABELS,
  type RoundupQualityReason,
  type RoundupQualityReviewReport,
} from "@/types/roundup-quality-review";

function ReasonPills({ reasons }: { reasons: string[] }) {
  if (reasons.length === 0) {
    return <span className="text-xs text-zinc-600">—</span>;
  }

  return (
    <div className="flex flex-wrap gap-1.5">
      {reasons.map((reason) => (
        <span
          key={reason}
          className="rounded-full border border-white/10 px-2 py-0.5 text-[10px] uppercase tracking-wider text-zinc-500"
        >
          {ROUNDUP_QUALITY_REASON_LABELS[reason as keyof typeof ROUNDUP_QUALITY_REASON_LABELS] ??
            reason.replaceAll("_", " ")}
        </span>
      ))}
    </div>
  );
}

function LabelPicker({
  lineId,
  onChange,
}: {
  lineId: string;
  onChange: () => void;
}) {
  const [labels, setLabels] = useState(() => getRoundupReviewLabels(lineId));

  return (
    <div className="flex flex-wrap gap-1.5">
      {ROUNDUP_REVIEW_LABELS.map(({ value, label }) => {
        const active = labels.includes(value);
        return (
          <Button
            key={value}
            type="button"
            variant={active ? "secondary" : "ghost"}
            size="sm"
            className="h-auto rounded-full px-2.5 py-1 text-[10px] uppercase tracking-wider"
            onClick={() => {
              const next = toggleRoundupReviewLabel(lineId, value);
              setLabels(next);
              onChange();
            }}
          >
            {label}
          </Button>
        );
      })}
    </div>
  );
}

export function RoundupQualityDebugPanel({
  report,
  onRefresh,
}: {
  report: RoundupQualityReviewReport;
  onRefresh: () => void;
}) {
  const [periodSlug, setPeriodSlug] = useState(report.periods[0]?.periodSlug ?? "");
  const [showSuppressedOnly, setShowSuppressedOnly] = useState(false);
  const [, bump] = useState(0);

  const period = useMemo(
    () => report.periods.find((row) => row.periodSlug === periodSlug) ?? report.periods[0],
    [report.periods, periodSlug],
  );

  const visibleItems =
    period?.items.filter((item) => !showSuppressedOnly || item.qualitySuppressed) ?? [];

  const topReasonEntry = Object.entries(report.byReason).sort((a, b) => b[1] - a[1])[0];
  const topReasonLabel = topReasonEntry
    ? ROUNDUP_QUALITY_REASON_LABELS[topReasonEntry[0] as RoundupQualityReason]
    : "—";

  return (
    <div className="space-y-6">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Candidates
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.totalCandidates}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Suppressed
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.totalSuppressed}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Selected
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.totalSelected}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Top reason
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm font-medium text-zinc-200">{topReasonLabel}</p>
          </CardContent>
        </Card>
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <label className="flex items-center gap-2 text-sm text-zinc-400">
          <select
            value={period?.periodSlug ?? ""}
            onChange={(event) => setPeriodSlug(event.target.value)}
            className="rounded-lg border border-white/10 bg-zinc-900 px-3 py-2 text-sm text-white"
          >
            {report.periods.map((row) => (
              <option key={row.periodSlug} value={row.periodSlug}>
                {row.periodLabel}
              </option>
            ))}
          </select>
        </label>
        <label className="flex items-center gap-2 text-sm text-zinc-400">
          <input
            type="checkbox"
            checked={showSuppressedOnly}
            onChange={(event) => setShowSuppressedOnly(event.target.checked)}
          />
          Suppressed only
        </label>
        <Button type="button" variant="ghost" size="sm" onClick={onRefresh}>
          Refresh labels
        </Button>
      </div>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">
            {period?.periodLabel ?? "Period"} · {visibleItems.length} lines
          </CardTitle>
          {period ? (
            <p className="text-xs text-zinc-500">
              {period.startDayKey} – {period.endDayKey} · {period.selectedCount} selected ·{" "}
              {period.suppressedCount} suppressed by quality
            </p>
          ) : null}
        </CardHeader>
        <CardContent>
          {visibleItems.length === 0 ? (
            <p className="text-sm text-zinc-500">No matching candidates.</p>
          ) : (
            <ul className="space-y-5">
              {visibleItems.map((item) => (
                <li
                  key={item.id}
                  className="space-y-3 rounded-xl border border-white/[0.06] bg-zinc-900/40 p-4"
                >
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <p className="max-w-2xl text-sm leading-relaxed text-zinc-200">{item.text}</p>
                    <div className="flex flex-wrap gap-2 text-[10px] uppercase tracking-wider">
                      <span className="rounded-full border border-white/10 px-2 py-0.5 text-zinc-500">
                        {item.signal.replaceAll("_", " ")}
                      </span>
                      <span className="rounded-full border border-white/10 px-2 py-0.5 text-zinc-500">
                        score {item.score}
                      </span>
                      {item.selected ? (
                        <span className="rounded-full border border-emerald-500/20 px-2 py-0.5 text-emerald-300/90">
                          selected
                        </span>
                      ) : item.qualitySuppressed ? (
                        <span className="rounded-full border border-amber-500/20 px-2 py-0.5 text-amber-300/90">
                          suppressed
                        </span>
                      ) : (
                        <span className="rounded-full border border-white/10 px-2 py-0.5 text-zinc-600">
                          not selected
                        </span>
                      )}
                    </div>
                  </div>

                  <div className="space-y-1">
                    <p className="text-[10px] uppercase tracking-wider text-zinc-600">Quality reasons</p>
                    <ReasonPills reasons={item.qualityReasons} />
                  </div>

                  <div className="space-y-1">
                    <p className="text-[10px] uppercase tracking-wider text-zinc-600">Source entries</p>
                    {item.entryIds.length === 0 ? (
                      <p className="text-xs text-zinc-600">None linked</p>
                    ) : (
                      <div className="flex flex-wrap gap-2">
                        {item.entryIds.map((entryId) => (
                          <Link
                            key={entryId}
                            href={`/entry/${entryId}`}
                            className="text-xs text-violet-300/90 hover:text-violet-200"
                          >
                            {entryId.slice(0, 8)}…
                          </Link>
                        ))}
                      </div>
                    )}
                  </div>

                  <div className="space-y-2">
                    <p className="text-[10px] uppercase tracking-wider text-zinc-600">Manual labels</p>
                    <LabelPicker
                      lineId={item.id}
                      onChange={() => {
                        bump((value) => value + 1);
                        onRefresh();
                      }}
                    />
                  </div>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
