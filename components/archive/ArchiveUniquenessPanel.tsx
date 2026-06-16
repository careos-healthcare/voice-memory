"use client";

import { useMemo } from "react";

import {
  ARCHIVE_UNIQUENESS_FOOTER,
  ARCHIVE_UNIQUENESS_HEADLINE,
  ARCHIVE_UNIQUENESS_LEAD_LINE,
} from "@/lib/archive/archive-uniqueness-copy";
import { buildArchiveUniquenessView } from "@/lib/archive/archive-uniqueness";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

type ArchiveUniquenessPanelProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
  variant?: "default" | "compact";
};

export function ArchiveUniquenessPanel({
  entriesOverride,
  className = "",
  variant = "default",
}: ArchiveUniquenessPanelProps) {
  const hydrated = useClientHydrated();
  const view = useMemo(
    () => (hydrated ? buildArchiveUniquenessView(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  if (!view) return null;

  return (
    <section
      className={cn(
        "rounded-2xl border border-white/[0.08] bg-white/[0.03] px-4 py-5 text-left",
        variant === "compact" && "py-4",
        className,
      )}
      data-testid="archive-uniqueness-panel"
    >
      <h2 className="text-sm font-medium text-zinc-300">{ARCHIVE_UNIQUENESS_HEADLINE}</h2>
      <p className="mt-3 text-sm leading-relaxed text-zinc-400">{ARCHIVE_UNIQUENESS_LEAD_LINE}</p>
      <p className="mt-2 text-sm leading-relaxed text-zinc-300/90">
        ArchiveMe can show:
      </p>
      <ul className="mt-2 list-inside list-disc space-y-1 text-sm text-zinc-400">
        {view.staticBullets.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
      {view.dynamicLines.length > 0 ? (
        <ul className="mt-3 space-y-1 border-t border-white/5 pt-3 text-xs text-zinc-500">
          {view.dynamicLines.map((line) => (
            <li key={line}>{line}</li>
          ))}
        </ul>
      ) : null}
      <p className="mt-3 text-xs leading-relaxed text-zinc-600">{ARCHIVE_UNIQUENESS_FOOTER}</p>
    </section>
  );
}
