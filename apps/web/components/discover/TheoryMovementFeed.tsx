"use client";

import Link from "next/link";

import { Card, CardContent } from "@/components/ui/card";
import { THEORY_MOVEMENT_COPY } from "@/lib/discover/theory-movement-copy";
import type { TheoryMovementFeedReport } from "@/types/theory-curiosity-engine";

interface TheoryMovementFeedProps {
  report: TheoryMovementFeedReport;
  className?: string;
}

export function TheoryMovementFeed({ report, className = "" }: TheoryMovementFeedProps) {
  if (!report.hasBaseline) return null;

  if (report.totalMovements === 0) {
    return (
      <Card className={`border-dashed border-white/5 ${className}`}>
        <CardContent className="py-10 text-center">
          <p className="text-sm font-medium text-zinc-400">{THEORY_MOVEMENT_COPY.emptyTitle}</p>
          <p className="mt-2 text-sm leading-relaxed text-zinc-600">
            {THEORY_MOVEMENT_COPY.emptyBody}
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <section
      className={`space-y-4 ${className}`}
      data-testid="theory-movement-feed"
      aria-labelledby="theory-movement-heading"
    >
      <div>
        <h2 id="theory-movement-heading" className="text-sm font-medium text-zinc-300">
          {THEORY_MOVEMENT_COPY.feedTitle}
        </h2>
        <p className="mt-1 text-xs leading-relaxed text-zinc-600">
          {THEORY_MOVEMENT_COPY.feedLead}
        </p>
      </div>
      <div className="space-y-3">
        {report.movements.map((movement) => (
          <article
            key={movement.id}
            className="rounded-xl border border-white/5 bg-black/20 px-4 py-4"
          >
            <p className="text-sm font-medium leading-snug text-zinc-200">{movement.headline}</p>
            <p className="mt-2 text-xs text-zinc-600">
              <span className="uppercase tracking-wider">{THEORY_MOVEMENT_COPY.whyLabel}</span>
              {": "}
              <span className="text-zinc-400">{movement.why}</span>
            </p>
            <Link
              href="/theories"
              className="mt-3 inline-block text-xs text-violet-400/80 hover:text-violet-300"
            >
              View theory
            </Link>
          </article>
        ))}
      </div>
    </section>
  );
}
