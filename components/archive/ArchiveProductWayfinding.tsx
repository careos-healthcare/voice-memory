"use client";

import Link from "next/link";

import {
  ARCHIVE_WAYFINDING_TO_ARCHIVE,
  ARCHIVE_WAYFINDING_TO_DISCOVER,
  DISCOVER_BACK_TO_ARCHIVE,
} from "@/lib/product/archive-product-copy";

type ArchiveProductWayfindingVariant = "discover" | "memory" | "journal";

interface ArchiveProductWayfindingProps {
  variant: ArchiveProductWayfindingVariant;
  className?: string;
}

export function ArchiveProductWayfinding({
  variant,
  className = "",
}: ArchiveProductWayfindingProps) {
  if (variant === "discover") {
    return (
      <div
        className={`rounded-2xl border border-violet-500/20 bg-violet-950/15 px-4 py-3 ${className}`}
        data-testid="archive-product-wayfinding-discover"
      >
        <p className="text-xs leading-relaxed text-zinc-500">{DISCOVER_BACK_TO_ARCHIVE}</p>
        <Link
          href="/archive-belief"
          className="mt-2 inline-flex text-sm font-medium text-violet-300 hover:text-violet-200"
        >
          {ARCHIVE_WAYFINDING_TO_ARCHIVE} →
        </Link>
      </div>
    );
  }

  const href = variant === "journal" ? "/archive-belief" : "/archive-belief";
  const secondary =
    variant === "memory" ? (
      <Link href="/discover" className="text-sm text-zinc-500 hover:text-zinc-300">
        {ARCHIVE_WAYFINDING_TO_DISCOVER} →
      </Link>
    ) : null;

  return (
    <div
      className={`flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-3 ${className}`}
      data-testid={`archive-product-wayfinding-${variant}`}
    >
      <Link href={href} className="text-sm font-medium text-violet-300 hover:text-violet-200">
        {ARCHIVE_WAYFINDING_TO_ARCHIVE} →
      </Link>
      {secondary}
    </div>
  );
}
