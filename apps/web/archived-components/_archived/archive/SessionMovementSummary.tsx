"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { ChevronDown } from "lucide-react";

import { buildSessionMovementSummary } from "@/lib/archive/session-movement-summary";
import { SESSION_MOVEMENT_HEADING } from "@/lib/archive/session-movement-summary-copy";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import {
  trackSessionMovementSummaryExpanded,
  trackSessionMovementSummarySeen,
} from "@/lib/metrics/session-movement-summary-events";
import type { SessionMovementSurface } from "@/types/session-movement-summary";
import type { JournalEntry } from "@/types/journal";

interface SessionMovementSummaryProps {
  className?: string;
  entriesOverride?: JournalEntry[];
  newEntryId?: string;
  surface: SessionMovementSurface;
}

export function SessionMovementSummary({
  className = "",
  entriesOverride,
  newEntryId,
  surface,
}: SessionMovementSummaryProps) {
  const hydrated = useClientHydrated();
  const [expanded, setExpanded] = useState(false);
  const seenRef = useRef(false);

  const summary = useMemo(() => {
    if (!hydrated) return null;
    return buildSessionMovementSummary(entriesOverride, {
      newEntryId,
      browseSurface: surface !== "record_complete" && surface !== "entry",
    });
  }, [hydrated, entriesOverride, newEntryId, surface]);

  useEffect(() => {
    if (!summary || seenRef.current) return;
    seenRef.current = true;
    trackSessionMovementSummarySeen({ kind: summary.kind, surface });
  }, [summary, surface]);

  if (!summary) return null;

  const toggleExpanded = () => {
    const next = !expanded;
    setExpanded(next);
    if (next) {
      trackSessionMovementSummaryExpanded({ kind: summary.kind, surface });
    }
  };

  return (
    <div
      className={`rounded-2xl border border-emerald-500/25 bg-emerald-950/20 px-4 py-4 text-left ${className}`}
      data-testid="session-movement-summary"
      data-movement-kind={summary.kind}
      data-surface={surface}
    >
      <p className="text-xs uppercase tracking-[0.16em] text-emerald-300/90">
        {SESSION_MOVEMENT_HEADING}
      </p>
      <p className="mt-2 text-sm font-medium text-zinc-100">{summary.headline}</p>
      {summary.detailLine ? (
        <p className="mt-1 text-sm tabular-nums text-emerald-200/90">{summary.detailLine}</p>
      ) : null}
      <button
        type="button"
        onClick={toggleExpanded}
        className="mt-3 flex w-full items-center justify-between gap-2 text-left text-xs text-zinc-500 hover:text-zinc-400"
        aria-expanded={expanded}
      >
        <span>Why the archive moved</span>
        <ChevronDown
          className={`h-4 w-4 shrink-0 transition ${expanded ? "rotate-180" : ""}`}
          aria-hidden
        />
      </button>
      {expanded ? (
        <p className="mt-2 text-sm leading-relaxed text-zinc-400">{summary.reason}</p>
      ) : null}
    </div>
  );
}
