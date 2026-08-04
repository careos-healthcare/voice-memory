"use client";

import Link from "next/link";

import { buildEvidenceLocker } from "@/lib/archive/evidence-locker";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import type { JournalEntry } from "@/types/journal";

interface EvidenceLockerProps {
  className?: string;
  entriesOverride?: JournalEntry[];
  compact?: boolean;
}

const TAG_LABELS: Record<string, string> = {
  supports: "supports",
  contradicts: "contradicts",
  cost: "cost",
  "cross-area": "cross-area",
  prediction: "prediction",
};

export function EvidenceLocker({
  className = "",
  entriesOverride,
  compact = false,
}: EvidenceLockerProps) {
  const hydrated = useClientHydrated();
  if (!hydrated) return null;

  const view = buildEvidenceLocker(entriesOverride);
  if (view.items.length === 0) return null;

  return (
    <section
      className={`rounded-2xl border border-white/10 bg-zinc-900/50 px-4 py-4 ${className}`}
      data-testid="evidence-locker"
      data-section="evidence-locker"
    >
      <p className="font-mono text-[10px] uppercase tracking-widest text-zinc-500">
        {view.title}
      </p>
      <p className="mt-2 text-sm text-zinc-400">{view.subtitle}</p>
      <ol className="mt-4 space-y-4">
        {view.items.map((item, index) => (
          <li
            key={item.id}
            className="border-l-2 border-violet-500/40 pl-3"
            data-testid={`evidence-locker-item-${index}`}
          >
            <div className="flex flex-wrap items-center gap-2 text-[10px] uppercase tracking-wide text-zinc-600">
              <span className="rounded border border-white/10 px-1.5 py-0.5 text-zinc-500">
                {TAG_LABELS[item.tag] ?? item.tag}
              </span>
              {item.dateLabel ? <span>{item.dateLabel}</span> : null}
            </div>
            <blockquote className="mt-2 text-sm leading-relaxed text-zinc-200">
              &ldquo;{item.quote}&rdquo;
            </blockquote>
            {!compact ? (
              <p className="mt-1 text-xs text-zinc-500">{item.whyItMatters}</p>
            ) : null}
            <p className="mt-1 text-xs text-zinc-600">
              Linked belief: <span className="text-zinc-400">{item.beliefText}</span>
            </p>
            {item.entryId ? (
              <Link
                href={`/memory/${item.entryId}`}
                className="mt-2 inline-block text-xs text-violet-300 hover:text-violet-200"
              >
                Source moment →
              </Link>
            ) : null}
          </li>
        ))}
      </ol>
    </section>
  );
}
