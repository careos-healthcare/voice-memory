"use client";

import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import type { ArchiveStateDeltaView } from "@/types/archive-state-snapshot";
import { cn } from "@/lib/utils";

type ArchiveStateDeltaCardProps = {
  delta: ArchiveStateDeltaView;
  className?: string;
  prominent?: boolean;
};

export function ArchiveStateDeltaCard({
  delta,
  className,
  prominent = false,
}: ArchiveStateDeltaCardProps) {
  if (!delta.hasChanges && !delta.subheadline) return null;

  return (
    <section
      className={cn(
        "rounded-2xl border px-4 py-4",
        prominent
          ? "border-violet-400/35 bg-violet-950/35"
          : "border-white/10 bg-black/25",
        className,
      )}
      data-testid="archive-state-delta-card"
      data-archive-grammar-section="change"
    >
      <h2
        className={cn(
          prominent ? "text-base font-semibold text-violet-100" : ARCHIVE_TYPO.sectionTitle,
        )}
      >
        {delta.headline}
      </h2>
      {delta.subheadline ? (
        <p className={cn(ARCHIVE_TYPO.body, "mt-2")}>{delta.subheadline}</p>
      ) : null}

      {delta.hasChanges ? (
        <dl className="mt-4 space-y-3">
          {delta.rows.map((row) => (
            <div
              key={`${row.kind}-${row.difference}`}
              className="grid grid-cols-[minmax(5rem,7rem)_1fr] gap-x-3 gap-y-1 text-sm"
              data-testid={`archive-state-delta-row-${row.kind}`}
            >
              <dt className="text-xs uppercase tracking-wide text-zinc-500">{row.label}</dt>
              <dd className="space-y-0.5">
                <div className="flex flex-wrap items-baseline gap-2 text-zinc-500">
                  <span className="text-xs">Then</span>
                  <span className="text-zinc-400">{row.then}</span>
                </div>
                <div className="flex flex-wrap items-baseline gap-2">
                  <span className="text-xs text-zinc-500">Now</span>
                  <span className="font-medium text-zinc-100">{row.now}</span>
                </div>
                <p className="text-sm text-violet-200/90">{row.difference}</p>
              </dd>
            </div>
          ))}
        </dl>
      ) : null}
    </section>
  );
}
