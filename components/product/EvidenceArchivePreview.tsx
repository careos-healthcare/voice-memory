"use client";

import Link from "next/link";

import {
  EVIDENCE_ARCHIVE_PREVIEW_BY_COUNT,
  EVIDENCE_ARCHIVE_PREVIEW_CTA,
} from "@/lib/product/evidence-archive-preview-copy";
import { buildArchiveValueSnapshot } from "@/lib/product/archive-value-progress";
import { trackActivationNextReflectionClicked } from "@/lib/product/activation-next-reflection";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import type { JournalEntry } from "@/types/journal";

interface EvidenceArchivePreviewProps {
  className?: string;
  entriesOverride?: JournalEntry[];
  surface?: string;
}

export function EvidenceArchivePreview({
  className = "",
  entriesOverride,
  surface = "memory",
}: EvidenceArchivePreviewProps) {
  const hydrated = useClientHydrated();
  const snapshot = buildArchiveValueSnapshot(entriesOverride);

  if (!hydrated || snapshot.reflectionCount < 1 || snapshot.reflectionCount > 5) {
    return null;
  }

  const count = Math.min(5, snapshot.reflectionCount) as 1 | 2 | 3 | 4 | 5;
  const message = EVIDENCE_ARCHIVE_PREVIEW_BY_COUNT[count];
  const showCta = snapshot.reflectionCount < 5;

  return (
    <div
      className={`rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4 ${className}`}
      data-testid="evidence-archive-preview"
      data-reflection-count={snapshot.reflectionCount}
    >
      <p className="text-xs uppercase tracking-wide text-zinc-500">Evidence archive building</p>
      <p className="mt-2 text-sm leading-relaxed text-zinc-300">{message}</p>
      {showCta ? (
        <Link
          href="/#recorder"
          onClick={() => trackActivationNextReflectionClicked(surface)}
          className="mt-3 inline-flex min-h-10 items-center text-sm font-medium text-violet-300 hover:text-violet-200"
        >
          {EVIDENCE_ARCHIVE_PREVIEW_CTA} →
        </Link>
      ) : null}
    </div>
  );
}
