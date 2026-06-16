"use client";

import { useState } from "react";
import Link from "next/link";
import { ChevronDown } from "lucide-react";

import { trackTheoryEvent, THEORY_EVENTS } from "@/lib/theories/theory-events";
import { buildTheoryUncertaintyFromChangeItem } from "@/lib/theories/theory-uncertainty";
import { TheoryConfidenceMovement } from "@/components/theories/TheoryConfidenceMovement";
import { TheoryUnderReviewPanel } from "@/components/theories/TheoryUnderReviewPanel";
import type { TheoryChangeItem } from "@/types/theory";

interface TheoryChangeItemCardProps {
  item: TheoryChangeItem;
}

function formatDelta(delta: number): string {
  if (delta === 0) return "0";
  return delta > 0 ? `+${delta}` : `${delta}`;
}

export function TheoryChangeItemCard({ item }: TheoryChangeItemCardProps) {
  const [expanded, setExpanded] = useState(false);
  const uncertainty = buildTheoryUncertaintyFromChangeItem(item);

  const onToggle = () => {
    const next = !expanded;
    setExpanded(next);
    if (next) {
      trackTheoryEvent(THEORY_EVENTS.theoryChangeExpanded, {
        theoryId: item.theoryId,
        category: item.category,
        source: item.source,
      });
    }
  };

  const onNavigate = () => {
    trackTheoryEvent(THEORY_EVENTS.theoryChangeClicked, {
      theoryId: item.theoryId,
      category: item.category,
      source: item.source,
    });
  };

  return (
    <article className="rounded-xl border border-white/5 bg-black/20 p-4">
      <p className="text-sm leading-relaxed text-zinc-200">{item.statement}</p>
      <TheoryConfidenceMovement
        input={{
          currentConfidence: item.confidence,
          delta: item.confidenceDelta,
        }}
        compact
        className="mt-3"
      />
      <TheoryUnderReviewPanel view={uncertainty} />
      <div className="mt-2 flex flex-wrap gap-3 text-xs text-zinc-600">
        <span>{formatDelta(item.confidenceDelta)} since last visit</span>
        <span>{new Date(item.updatedAt).toLocaleDateString()}</span>
      </div>
      <p className="mt-2 text-xs leading-relaxed text-zinc-500">{item.shortReason}</p>
      <div className="mt-3 flex flex-wrap items-center gap-3">
        <button
          type="button"
          className="flex items-center gap-1 text-xs text-zinc-500 hover:text-violet-300"
          onClick={onToggle}
          aria-expanded={expanded}
        >
          <ChevronDown
            className={`h-3.5 w-3.5 transition-transform ${expanded ? "rotate-180" : ""}`}
          />
          {expanded ? "Less" : "More"}
        </button>
        <Link
          href={`/theories`}
          onClick={onNavigate}
          className="text-xs text-violet-400/80 hover:text-violet-300"
        >
          Open theory
        </Link>
      </div>
      {expanded ? (
        <p className="mt-2 text-[10px] uppercase tracking-wider text-zinc-600">
          Source: {item.source.replace("_", " ")}
        </p>
      ) : null}
    </article>
  );
}
