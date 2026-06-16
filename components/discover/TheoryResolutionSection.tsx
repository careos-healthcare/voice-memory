"use client";

import { TheoryCard } from "@/components/theories/TheoryCard";
import { DISCOVER_PAGE } from "@/lib/discover/discover-copy";
import type { TheoryResolutionFeedReport } from "@/types/theory";

function ResolutionGroup({
  title,
  theories,
}: {
  title: string;
  theories: import("@/types/theory").Theory[];
}) {
  if (theories.length === 0) return null;
  return (
    <div className="space-y-3">
      <h3 className="text-xs font-medium uppercase tracking-wide text-zinc-500">
        {title}
      </h3>
      <div className="space-y-3">
        {theories.map((theory) => (
          <TheoryCard key={theory.id} theory={theory} />
        ))}
      </div>
    </div>
  );
}

interface TheoryResolutionSectionProps {
  feed: TheoryResolutionFeedReport;
}

export function TheoryResolutionSection({ feed }: TheoryResolutionSectionProps) {
  if (feed.total === 0) return null;

  return (
    <section className="space-y-4 border-t border-white/5 pt-10">
      <div>
        <h2 className="text-sm font-medium text-zinc-300">
          {DISCOVER_PAGE.resolutionSectionTitle}
        </h2>
        <p className="mt-1 text-sm leading-relaxed text-zinc-600">
          {DISCOVER_PAGE.resolutionSectionLead}
        </p>
      </div>
      <ResolutionGroup
        title={DISCOVER_PAGE.resolutionResolvedTitle}
        theories={feed.resolved}
      />
      <ResolutionGroup
        title={DISCOVER_PAGE.resolutionRetiredTitle}
        theories={feed.retired}
      />
    </section>
  );
}
