"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";

import {
  buildArchiveValueSnapshot,
  shouldShowArchiveValueBanner,
} from "@/lib/product/archive-value-progress";
import { ARCHIVE_VALUE_POSITIONING } from "@/lib/product/archive-value-copy";
import {
  trackArchiveValueBannerShown,
  trackArchiveValueCtaClicked,
} from "@/lib/product/archive-value-metrics";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { PATTERN_REVIEW_TARGET } from "@/lib/product/archive-value-copy";
import type { JournalEntry } from "@/types/journal";

interface ArchiveValueBannerProps {
  className?: string;
  compact?: boolean;
  entriesOverride?: JournalEntry[];
}

export function ArchiveValueBanner({
  className = "",
  compact = false,
  entriesOverride,
}: ArchiveValueBannerProps) {
  const hydrated = useClientHydrated();
  const shownRef = useRef(false);
  const [snapshot, setSnapshot] = useState(() =>
    buildArchiveValueSnapshot(entriesOverride),
  );

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const next = buildArchiveValueSnapshot(entriesOverride);
      setSnapshot(next);
    });
    return () => cancelAnimationFrame(id);
  }, [entriesOverride]);

  useEffect(() => {
    if (!hydrated || shownRef.current) return;
    if (!shouldShowArchiveValueBanner(snapshot.reflectionCount)) return;
    shownRef.current = true;
    trackArchiveValueBannerShown(snapshot.reflectionCount, snapshot.stage);
  }, [hydrated, snapshot.reflectionCount, snapshot.stage]);

  const show = useMemo(
    () => hydrated && shouldShowArchiveValueBanner(snapshot.reflectionCount),
    [hydrated, snapshot.reflectionCount],
  );

  if (!show) return null;

  const padding = compact ? "px-3 py-3" : "px-4 py-4";

  return (
    <div
      className={`rounded-2xl border border-emerald-500/20 bg-emerald-950/15 text-left ${padding} ${className}`}
      data-testid="archive-value-banner"
    >
      <p className="text-xs uppercase tracking-wide text-emerald-200/80">Archive value</p>
      <p className="mt-2 text-sm font-medium text-emerald-50/95">{snapshot.valueCopy}</p>
      {!compact ? (
        <p className="mt-1 text-xs text-zinc-500">{ARCHIVE_VALUE_POSITIONING.archiveHarderToFool}</p>
      ) : null}
      <p className="mt-2 text-sm text-zinc-400">
        {Math.min(snapshot.reflectionCount, PATTERN_REVIEW_TARGET)}/{PATTERN_REVIEW_TARGET}{" "}
        reflections toward pattern review · {snapshot.progressPercent}%
      </p>
      <p className="mt-1 text-xs text-zinc-500">{snapshot.nextMilestoneCopy}</p>

      <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-zinc-500">
        {snapshot.repeatedThemeCount > 0 ? (
          <span>{snapshot.repeatedThemeCount} repeated theme{snapshot.repeatedThemeCount === 1 ? "" : "s"}</span>
        ) : null}
        {snapshot.theoriesUnderReviewCount > 0 ? (
          <span>
            {snapshot.theoriesUnderReviewCount} theor
            {snapshot.theoriesUnderReviewCount === 1 ? "y" : "ies"} under review
          </span>
        ) : null}
        {snapshot.crossLifeAreaPatternCount > 0 ? (
          <span>{snapshot.crossLifeAreaPatternCount} cross-life-area</span>
        ) : null}
        {snapshot.contradictionCount > 0 ? (
          <span>{snapshot.contradictionCount} contradiction signal{snapshot.contradictionCount === 1 ? "" : "s"}</span>
        ) : null}
        {snapshot.costEvidenceCount > 0 ? (
          <span>{snapshot.costEvidenceCount} cost evidence</span>
        ) : null}
      </div>

      <Link
        href={snapshot.ctaHref}
        className="mt-3 inline-block text-sm text-emerald-300 underline-offset-2 hover:text-emerald-200 hover:underline"
        onClick={() =>
          trackArchiveValueCtaClicked(snapshot.reflectionCount, snapshot.stage)
        }
      >
        {snapshot.ctaLabel}
      </Link>
    </div>
  );
}
