"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { ChevronDown } from "lucide-react";

import { buildHardToReproduceProofView } from "@/lib/archive/hard-to-reproduce-proof";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import {
  trackHardToReproduceProofExpanded,
  trackHardToReproduceProofSeen,
} from "@/lib/metrics/hard-to-reproduce-proof-events";
import type { JournalEntry } from "@/types/journal";

interface HardToReproduceProofProps {
  className?: string;
  entriesOverride?: JournalEntry[];
  surface: string;
  defaultExpanded?: boolean;
}

export function HardToReproduceProof({
  className = "",
  entriesOverride,
  surface,
  defaultExpanded = false,
}: HardToReproduceProofProps) {
  const hydrated = useClientHydrated();
  const [expanded, setExpanded] = useState(defaultExpanded);
  const seenRef = useRef(false);

  const proof = useMemo(
    () => (hydrated ? buildHardToReproduceProofView(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  useEffect(() => {
    if (!proof || seenRef.current) return;
    seenRef.current = true;
    trackHardToReproduceProofSeen({ surface });
  }, [proof, surface]);

  if (!proof || proof.lines.length === 0) return null;

  const toggle = () => {
    const next = !expanded;
    setExpanded(next);
    if (next) trackHardToReproduceProofExpanded({ surface });
  };

  return (
    <div
      className={`rounded-2xl border border-violet-500/20 bg-violet-950/15 px-4 py-4 text-left ${className}`}
      data-testid="hard-to-reproduce-proof"
    >
      <button
        type="button"
        onClick={toggle}
        className="flex w-full items-center justify-between gap-2 text-left"
        aria-expanded={expanded}
      >
        <p className="text-xs uppercase tracking-[0.16em] text-violet-300/90">
          Hard to reproduce elsewhere
        </p>
        <ChevronDown
          className={`h-4 w-4 shrink-0 text-zinc-500 transition ${expanded ? "rotate-180" : ""}`}
          aria-hidden
        />
      </button>
      {expanded ? (
        <ul className="mt-3 space-y-2 text-sm leading-relaxed text-zinc-300">
          {proof.lines.map((line) => (
            <li key={line.id}>{line.text}</li>
          ))}
        </ul>
      ) : (
        <p className="mt-2 text-sm text-zinc-400">{proof.lines[0]?.text}</p>
      )}
    </div>
  );
}
