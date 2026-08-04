"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";

import { Card, CardContent } from "@/components/ui/card";
import { buildActivationTheoryPreview } from "@/lib/product/activation-theory-preview";
import {
  observeActivationBottleneckMilestones,
  trackActivationTheoryPreviewClicked,
  trackActivationTheoryPreviewShown,
} from "@/lib/product/activation-bottleneck-metrics";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ActivationTheoryPreview } from "@/types/activation-theory-preview";
import type { JournalEntry } from "@/types/journal";

interface ActivationTheoryPreviewProps {
  className?: string;
  compact?: boolean;
  entriesOverride?: JournalEntry[];
}

export function ActivationTheoryPreview({
  className = "",
  compact = false,
  entriesOverride,
}: ActivationTheoryPreviewProps) {
  const entries = useMemo(
    () => entriesOverride ?? getMemoryEligibleEntries(),
    [entriesOverride],
  );
  const [preview, setPreview] = useState<ActivationTheoryPreview | null>(null);
  const shownRef = useRef(false);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const next = buildActivationTheoryPreview(entries);
      setPreview(next);
      observeActivationBottleneckMilestones(next?.reflectionCount ?? entries.length);
    });
    return () => cancelAnimationFrame(id);
  }, [entries]);

  useEffect(() => {
    if (!preview || shownRef.current) return;
    shownRef.current = true;
    trackActivationTheoryPreviewShown(preview.reflectionCount);
  }, [preview]);

  if (!preview) return null;

  const padding = compact ? "p-4" : "p-5";

  return (
    <Card
      className={`border border-amber-500/20 bg-amber-950/10 ${className}`}
      data-testid="activation-theory-preview"
    >
      <CardContent className={`space-y-3 ${padding}`}>
        <p className="text-xs font-medium text-amber-200/90">{preview.title}</p>
        <p className="text-[11px] uppercase tracking-wide text-zinc-500">
          {preview.confidenceLabel}
        </p>
        <p className="text-sm leading-relaxed text-zinc-200">{preview.possibleTheory}</p>
        {!compact ? (
          <p className="text-xs text-zinc-500">
            {preview.evidenceCount} moment{preview.evidenceCount === 1 ? "" : "s"} in this
            early read
          </p>
        ) : null}
        <p className="text-sm leading-relaxed text-amber-100/80">{preview.unlockCopy}</p>
        <p className="text-sm leading-relaxed text-violet-200/90">{preview.nextReflectionCopy}</p>
        <p className="text-xs text-zinc-600">{preview.disclaimer}</p>
        <Link
          href="/#recorder"
          className="inline-block text-xs text-violet-300 underline-offset-2 hover:text-violet-200 hover:underline"
          onClick={() => trackActivationTheoryPreviewClicked(preview.reflectionCount)}
        >
          Record your next moment
        </Link>
      </CardContent>
    </Card>
  );
}
