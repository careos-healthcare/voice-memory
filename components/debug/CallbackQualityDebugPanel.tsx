"use client";

import { useMemo, useState } from "react";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  getCallbackReviewLabels,
  toggleCallbackReviewLabel,
} from "@/lib/debug/callback-review-labels";
import {
  CALLBACK_REVIEW_LABELS,
  REWRITE_FLAG_LABELS,
  type CallbackQualityReviewReport,
  type CallbackReviewItem,
  type CallbackReviewLabel,
} from "@/types/callback-quality-review";

function SignalRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3 text-xs">
      <span className="text-zinc-500">{label}</span>
      <span className="tabular-nums text-zinc-300">{value}</span>
    </div>
  );
}

function CallbackReviewCard({
  item,
  onLabelsChange,
}: {
  item: CallbackReviewItem;
  onLabelsChange: () => void;
}) {
  const [labels, setLabels] = useState<CallbackReviewLabel[]>(() =>
    getCallbackReviewLabels(item.id),
  );

  const toggleLabel = (label: CallbackReviewLabel) => {
    const next = toggleCallbackReviewLabel(item.id, label);
    setLabels(next);
    onLabelsChange();
  };

  return (
    <Card className={item.rewriteFlags.length > 0 ? "border-amber-500/25" : undefined}>
      <CardHeader className="space-y-3 pb-3">
        <div className="flex flex-wrap items-center gap-2">
          <span className="rounded-full bg-white/5 px-2 py-0.5 text-[10px] uppercase tracking-wider text-zinc-500">
            {item.kind.replace(/_/g, " ")}
          </span>
          {item.rewriteFlags.length > 0 ? (
            <span className="rounded-full bg-amber-500/10 px-2 py-0.5 text-[10px] text-amber-200/90">
              Rewrite candidate
            </span>
          ) : null}
          <span className="text-[10px] tabular-nums text-zinc-600">
            weight {item.emotionalWeight} · conf {item.confidence}
          </span>
        </div>
        <CardTitle className="text-base font-normal leading-relaxed text-zinc-200">
          {item.text}
        </CardTitle>
        <p className="text-xs leading-relaxed text-zinc-500">
          Surfaces: {item.surfaces.join(", ")}
        </p>
      </CardHeader>

      <CardContent className="space-y-5 border-t border-white/5 pt-4">
        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
            Why it surfaced
          </p>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">{item.whySurfaced}</p>
        </div>

        {(item.beforeQuote || item.afterQuote) && (
          <div className="grid gap-3 sm:grid-cols-2">
            {item.beforeQuote ? (
              <div className="rounded-xl bg-white/[0.03] p-3">
                <p className="text-[10px] uppercase tracking-wider text-zinc-600">Before</p>
                {item.beforeDateLabel ? (
                  <p className="mt-1 text-[10px] text-zinc-600">{item.beforeDateLabel}</p>
                ) : null}
                <p className="mt-2 text-sm leading-relaxed text-zinc-400">{item.beforeQuote}</p>
              </div>
            ) : null}
            {item.afterQuote ? (
              <div className="rounded-xl bg-white/[0.03] p-3">
                <p className="text-[10px] uppercase tracking-wider text-zinc-600">After</p>
                {item.afterDateLabel ? (
                  <p className="mt-1 text-[10px] text-zinc-600">{item.afterDateLabel}</p>
                ) : null}
                <p className="mt-2 text-sm leading-relaxed text-zinc-400">{item.afterQuote}</p>
              </div>
            ) : null}
          </div>
        )}

        {item.sourceEntries.length > 0 ? (
          <div>
            <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
              Source entries
            </p>
            <ul className="mt-2 space-y-2">
              {item.sourceEntries.map((entry) => (
                <li key={entry.id} className="rounded-xl bg-white/[0.03] px-3 py-2">
                  <Link href={entry.href} className="text-sm text-violet-300 hover:text-violet-200">
                    {entry.dateLabel}
                  </Link>
                  {entry.snippet ? (
                    <p className="mt-1 text-xs leading-relaxed text-zinc-500">{entry.snippet}</p>
                  ) : null}
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
            Retention observation
          </p>
          <div className="mt-2 space-y-1.5 rounded-xl bg-white/[0.03] p-3">
            <SignalRow label="Surfaced" value={String(item.retention.surfaced)} />
            <SignalRow label="Ignored" value={String(item.retention.ignored)} />
            <SignalRow label="Rereads" value={String(item.retention.reread)} />
            <SignalRow label="Revisits" value={String(item.retention.revisit)} />
            <SignalRow label="New recordings" value={String(item.retention.recording)} />
            <SignalRow label="Bookmarked" value={String(item.retention.bookmark)} />
            <SignalRow label="Copied / shared" value={String(item.retention.copied)} />
          </div>
        </div>

        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
            Interaction signals
          </p>
          <div className="mt-2 space-y-1.5 rounded-xl bg-white/[0.03] p-3">
            <SignalRow label="Rereads" value={String(item.signals.rereadCount)} />
            <SignalRow label="Revisited entries" value={String(item.signals.revisitCount)} />
            <SignalRow label="Bookmarked" value={item.signals.bookmarked ? "yes" : "no"} />
            <SignalRow
              label="Memory moment copied"
              value={item.signals.memoryMomentCopied ? "yes" : "no"}
            />
            <SignalRow label="Dwell time" value={`${Math.round(item.signals.dwellMs / 1000)}s`} />
            <SignalRow
              label="Continued follow-up"
              value={item.continuedFollowup ? "yes" : "no"}
            />
          </div>
        </div>

        {item.followupPrompt ? (
          <div>
            <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
              Follow-up prompt
            </p>
            <p className="mt-2 text-sm leading-relaxed text-zinc-500">{item.followupPrompt}</p>
          </div>
        ) : null}

        {item.rewriteFlags.length > 0 ? (
          <div>
            <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
              Rewrite flags
            </p>
            <ul className="mt-2 flex flex-wrap gap-2">
              {item.rewriteFlags.map((flag) => (
                <li
                  key={flag}
                  className="rounded-full bg-amber-500/10 px-2 py-1 text-[10px] text-amber-100/90"
                >
                  {REWRITE_FLAG_LABELS[flag]}
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-zinc-600">
            Manual review
          </p>
          <div className="mt-2 flex flex-wrap gap-2">
            {CALLBACK_REVIEW_LABELS.map(({ value, label }) => {
              const active = labels.includes(value);
              return (
                <Button
                  key={value}
                  type="button"
                  size="sm"
                  variant={active ? "default" : "secondary"}
                  className="h-auto px-2 py-1 text-[11px]"
                  onClick={() => toggleLabel(value)}
                >
                  {label}
                </Button>
              );
            })}
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

export function CallbackQualityDebugPanel({
  report,
  onRefresh,
}: {
  report: CallbackQualityReviewReport;
  onRefresh: () => void;
}) {
  const [filter, setFilter] = useState<"all" | "rewrite">("all");
  const [, bump] = useState(0);

  const items = useMemo(() => {
    if (filter === "rewrite") {
      return report.items.filter((item) => item.rewriteFlags.length > 0);
    }
    return report.items;
  }, [filter, report.items]);

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Callbacks
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.items.length}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Rewrite candidates
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">
              {report.rewriteCandidateCount}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Labeled
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.labeledCount}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Filter
            </CardTitle>
          </CardHeader>
          <CardContent className="flex gap-2">
            <Button
              type="button"
              size="sm"
              variant={filter === "all" ? "default" : "secondary"}
              onClick={() => setFilter("all")}
            >
              All
            </Button>
            <Button
              type="button"
              size="sm"
              variant={filter === "rewrite" ? "default" : "secondary"}
              onClick={() => setFilter("rewrite")}
            >
              Rewrite
            </Button>
          </CardContent>
        </Card>
      </div>

      {items.length === 0 ? (
        <Card>
          <CardContent className="py-12 text-center text-sm text-zinc-500">
            No callbacks match this filter yet.
          </CardContent>
        </Card>
      ) : (
        items.map((item) => (
          <CallbackReviewCard
            key={`${item.kind}-${item.id}`}
            item={item}
            onLabelsChange={() => {
              bump((value) => value + 1);
              onRefresh();
            }}
          />
        ))
      )}
    </div>
  );
}
