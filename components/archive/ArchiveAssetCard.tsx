"use client";

import { useEffect, useMemo, useRef } from "react";
import Link from "next/link";

import { buildArchiveAssetValueView } from "@/lib/archive/archive-asset-value";
import {
  ARCHIVE_ASSET_HARD_TO_REBUILD,
  ARCHIVE_ASSET_LEAD,
  ARCHIVE_ASSET_SUBLEAD,
} from "@/lib/archive/archive-asset-value-copy";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import {
  trackArchiveAssetCardSeen,
  trackArchiveAssetExportClicked,
} from "@/lib/metrics/archive-asset-value-events";
import type { JournalEntry } from "@/types/journal";

interface ArchiveAssetCardProps {
  className?: string;
  entriesOverride?: JournalEntry[];
  surface: string;
  showExportLink?: boolean;
}

export function ArchiveAssetCard({
  className = "",
  entriesOverride,
  surface,
  showExportLink = false,
}: ArchiveAssetCardProps) {
  const hydrated = useClientHydrated();
  const seenRef = useRef(false);

  const asset = useMemo(
    () => (hydrated ? buildArchiveAssetValueView(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  useEffect(() => {
    if (!asset || seenRef.current) return;
    seenRef.current = true;
    trackArchiveAssetCardSeen({ surface });
  }, [asset, surface]);

  if (!asset) return null;

  const stats = [
    `${asset.totalReflections} reflection${asset.totalReflections === 1 ? "" : "s"}`,
    `${asset.daysCovered} day${asset.daysCovered === 1 ? "" : "s"} covered`,
    asset.monthsCovered > 1 ? `${asset.monthsCovered} months in archive` : null,
    asset.recurringBeliefsTracked > 0
      ? `${asset.recurringBeliefsTracked} belief${asset.recurringBeliefsTracked === 1 ? "" : "s"} tracked`
      : null,
    asset.evidenceQuotesStored > 0
      ? `${asset.evidenceQuotesStored} evidence quote${asset.evidenceQuotesStored === 1 ? "" : "s"} stored`
      : null,
    asset.beliefChangesRecorded > 0
      ? `${asset.beliefChangesRecorded} belief change${asset.beliefChangesRecorded === 1 ? "" : "s"} recorded`
      : null,
    asset.firstReflectionLabel ? `First reflection: ${asset.firstReflectionLabel}` : null,
  ].filter(Boolean) as string[];

  return (
    <div
      className={`rounded-2xl border border-zinc-700/45 bg-zinc-900/35 px-4 py-4 text-left ${className}`}
      data-testid="archive-asset-card"
    >
      <p className="text-sm leading-relaxed text-zinc-200">{ARCHIVE_ASSET_LEAD}</p>
      <p className="mt-2 text-sm leading-relaxed text-zinc-400">{ARCHIVE_ASSET_SUBLEAD}</p>
      <ul className="mt-3 list-inside list-disc space-y-1 text-sm text-zinc-500">
        {stats.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>
      <p className="mt-3 text-xs text-violet-300/90">{ARCHIVE_ASSET_HARD_TO_REBUILD}</p>
      {showExportLink ? (
        <Link
          href="/export"
          className="mt-3 inline-block text-sm text-violet-300 hover:text-violet-200"
          onClick={() => trackArchiveAssetExportClicked({ surface })}
        >
          Export archive →
        </Link>
      ) : null}
    </div>
  );
}
