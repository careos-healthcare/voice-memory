"use client";

import { useEffect, useMemo, useRef } from "react";

import { buildEffortCompoundsVisibility } from "@/lib/archive/effort-compounds";
import {
  EFFORT_COMPOUNDS_HEADING,
  EFFORT_COMPOUNDS_LINES,
} from "@/lib/archive/effort-compounds-copy";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { trackEffortCompoundsSeen } from "@/lib/metrics/effort-compounds-events";
import type { JournalEntry } from "@/types/journal";

interface EffortCompoundsPanelProps {
  className?: string;
  entriesOverride?: JournalEntry[];
  surface?: "export" | "default";
}

export function EffortCompoundsPanel({
  className = "",
  entriesOverride,
  surface = "default",
}: EffortCompoundsPanelProps) {
  const hydrated = useClientHydrated();
  const seenRef = useRef(false);

  const visibility = useMemo(() => {
    if (!hydrated) return null;
    return buildEffortCompoundsVisibility(entriesOverride, {
      surface: surface === "export" ? "export" : undefined,
    });
  }, [hydrated, entriesOverride, surface]);

  useEffect(() => {
    if (!visibility?.show || !visibility.trigger || seenRef.current) return;
    seenRef.current = true;
    trackEffortCompoundsSeen({
      reflectionCount: visibility.reflectionCount,
      trigger: visibility.trigger,
    });
  }, [visibility?.show, visibility?.trigger, visibility?.reflectionCount]);

  if (!visibility?.show) return null;

  return (
    <div
      className={`rounded-2xl border border-zinc-700/45 bg-zinc-900/35 px-4 py-4 text-left ${className}`}
      data-testid="effort-compounds-panel"
    >
      <p className="text-xs uppercase tracking-[0.16em] text-zinc-500">{EFFORT_COMPOUNDS_HEADING}</p>
      <ul className="mt-3 space-y-2 text-sm leading-relaxed text-zinc-400">
        {EFFORT_COMPOUNDS_LINES.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>
    </div>
  );
}
