"use client";

import { useState } from "react";
import { ChevronDown } from "lucide-react";

import { DISCOVER_PAGE } from "@/lib/discover/discover-copy";
import type { EvidenceMovement, EvidenceMovementKind } from "@/types/evidence-feed";

interface EvidenceFeedSectionProps {
  movements: EvidenceMovement[];
  hasBaseline: boolean;
}

function kindLabel(kind: EvidenceMovementKind): string {
  return DISCOVER_PAGE.evidenceKindLabels[kind];
}

function EvidenceMovementCard({ movement }: { movement: EvidenceMovement }) {
  const [expanded, setExpanded] = useState(false);
  const hasQuotes = movement.quotes.length > 0;
  const hasExtra =
    hasQuotes ||
    (movement.costEvidenceLines?.length ?? 0) > 0 ||
    (movement.lifeAreas?.length ?? 0) > 0;

  return (
    <article className="rounded-xl border border-white/5 bg-black/20 p-4">
      <p className="text-[10px] uppercase tracking-wider text-violet-400/80">
        {kindLabel(movement.kind)}
      </p>
      <p className="mt-1 text-xs text-zinc-500 line-clamp-2">{movement.theoryStatement}</p>
      <p className="mt-2 text-sm leading-relaxed text-zinc-400">{movement.summary}</p>
      {movement.confidenceDelta !== undefined &&
      movement.previousConfidence !== undefined ? (
        <p className="mt-1 text-xs text-zinc-600">
          {movement.previousConfidence} → {movement.currentConfidence}
        </p>
      ) : null}
      {movement.costEvidenceLines?.map((line) => (
        <p key={line} className="mt-2 text-xs leading-relaxed text-zinc-500">
          {line}
        </p>
      ))}
      {hasExtra ? (
        <>
          <button
            type="button"
            className="mt-3 flex items-center gap-1 text-xs text-zinc-500 hover:text-violet-300"
            onClick={() => setExpanded(!expanded)}
            aria-expanded={expanded}
          >
            <ChevronDown
              className={`h-3.5 w-3.5 transition-transform ${expanded ? "rotate-180" : ""}`}
            />
            {expanded ? "Hide quotes" : "Show quotes"}
          </button>
          {expanded ? (
            <div className="mt-2 space-y-2">
              {movement.quotes.map((q) => (
                <blockquote
                  key={`${movement.theoryId}-${q.entryId}`}
                  className="border-l-2 border-violet-400/30 pl-3 text-sm text-zinc-400"
                >
                  <span className="text-[10px] text-zinc-600">{q.dateLabel}</span>
                  <p className="mt-0.5">&ldquo;{q.quote}&rdquo;</p>
                </blockquote>
              ))}
            </div>
          ) : null}
        </>
      ) : null}
    </article>
  );
}

export function EvidenceFeedSection({ movements, hasBaseline }: EvidenceFeedSectionProps) {
  if (!hasBaseline) return null;

  return (
    <section className="space-y-3">
      <h2 className="text-sm font-medium text-zinc-300">{DISCOVER_PAGE.evidenceSectionTitle}</h2>
      {movements.length === 0 ? (
        <p className="rounded-xl border border-dashed border-white/5 bg-black/10 px-4 py-6 text-center text-sm leading-relaxed text-zinc-500">
          {DISCOVER_PAGE.evidenceEmpty}
        </p>
      ) : (
        <div className="space-y-3">
          {movements.map((movement) => (
            <EvidenceMovementCard
              key={`${movement.kind}-${movement.theoryId}-${movement.summary.slice(0, 24)}`}
              movement={movement}
            />
          ))}
        </div>
      )}
    </section>
  );
}
