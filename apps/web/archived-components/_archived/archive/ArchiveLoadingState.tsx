"use client";

import { ArchiveSkeleton, type ArchiveSkeletonVariant } from "@/archived-components/_archived/archive/ArchiveSkeleton";
import { ArchiveTransition } from "@/archived-components/_archived/archive/ArchiveTransition";
import { cn } from "@/lib/utils";

type ArchiveLoadingStateProps = {
  variant?: ArchiveSkeletonVariant;
  className?: string;
  /** Screen-reader label only — never shown as visible text */
  ariaLabel?: string;
};

/**
 * Archive loading — skeleton only, no raw "Loading…" copy.
 */
export function ArchiveLoadingState({
  variant = "commandCenter",
  className,
  ariaLabel = "Archive preparing",
}: ArchiveLoadingStateProps) {
  return (
    <ArchiveTransition mode="fade" testId="archive-loading-state">
      <div
        className={cn(className)}
        role="status"
        aria-live="polite"
        aria-busy="true"
        aria-label={ariaLabel}
      >
        <span className="sr-only">{ariaLabel}</span>
        <ArchiveSkeleton variant={variant} />
      </div>
    </ArchiveTransition>
  );
}
