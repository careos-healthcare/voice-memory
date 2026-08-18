"use client";

import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

export type ArchiveSkeletonVariant =
  | "commandCenter"
  | "timeline"
  | "card"
  | "movement"
  | "metrics"
  | "discoverFeed"
  | "pageHeader";

type ArchiveSkeletonProps = {
  variant: ArchiveSkeletonVariant;
  className?: string;
};

/**
 * Archive skeleton presets — no visible loading copy.
 */
export function ArchiveSkeleton({ variant, className }: ArchiveSkeletonProps) {
  switch (variant) {
    case "pageHeader":
      return (
        <div className={cn("space-y-3", className)} data-testid="archive-skeleton-header">
          <Skeleton className="h-3 w-28 rounded-md" />
          <Skeleton className="h-8 w-56 max-w-full rounded-lg" />
          <Skeleton className="h-4 w-full max-w-md rounded-md" />
        </div>
      );
    case "commandCenter":
      return (
        <div
          className={cn(
            "space-y-4 rounded-2xl border border-violet-500/20 bg-violet-950/15 p-4 sm:p-5",
            className,
          )}
          data-testid="archive-skeleton-command-center"
        >
          <div className="flex justify-between gap-4 border-b border-white/10 pb-3">
            <div className="space-y-2 flex-1">
              <Skeleton className="h-3 w-24" />
              <Skeleton className="h-3 w-40" />
            </div>
            <div className="flex gap-3">
              <Skeleton className="h-10 w-16 rounded-lg" />
              <Skeleton className="h-10 w-20 rounded-lg" />
            </div>
          </div>
          <Skeleton className="h-7 w-full max-w-lg rounded-lg" />
          <div className="grid gap-3 sm:grid-cols-3">
            <Skeleton className="h-14 rounded-lg" />
            <Skeleton className="h-14 rounded-lg" />
            <Skeleton className="h-14 rounded-lg" />
          </div>
          <div className="grid gap-4 lg:grid-cols-2">
            <Skeleton className="h-28 rounded-xl" />
            <Skeleton className="h-28 rounded-xl" />
          </div>
          <Skeleton className="h-24 rounded-xl" />
          <Skeleton className="h-4 w-3/4 max-w-sm rounded-md" />
        </div>
      );
    case "timeline":
      return (
        <div className={cn("space-y-4 border-l border-violet-500/20 pl-4", className)} data-testid="archive-skeleton-timeline">
          {[0, 1, 2].map((i) => (
            <div key={i} className="space-y-2 pb-4">
              <Skeleton className="h-4 w-24" />
              <Skeleton className="h-7 w-14 rounded-md" />
              <Skeleton className="h-3 w-full max-w-xs rounded-md" />
            </div>
          ))}
        </div>
      );
    case "metrics":
      return (
        <div className={cn("grid gap-3 sm:grid-cols-3", className)} data-testid="archive-skeleton-metrics">
          <Skeleton className="h-14 rounded-lg" />
          <Skeleton className="h-14 rounded-lg" />
          <Skeleton className="h-14 rounded-lg" />
        </div>
      );
    case "card":
      return (
        <div
          className={cn("space-y-3 rounded-2xl border border-white/10 p-4", className)}
          data-testid="archive-skeleton-card"
        >
          <Skeleton className="h-4 w-32 rounded-md" />
          <Skeleton className="h-16 w-full rounded-lg" />
          <Skeleton className="h-3 w-2/3 max-w-sm rounded-md" />
        </div>
      );
    case "movement":
      return (
        <div
          className={cn(
            "space-y-2 rounded-2xl border border-violet-500/20 bg-violet-950/15 p-4",
            className,
          )}
          data-testid="archive-skeleton-movement"
        >
          <Skeleton className="h-3 w-28" />
          <Skeleton className="h-5 w-48 max-w-full rounded-md" />
          <Skeleton className="h-4 w-36 rounded-md" />
        </div>
      );
    case "discoverFeed":
      return (
        <div className={cn("space-y-6", className)} data-testid="archive-skeleton-discover">
          <Skeleton className="h-24 w-full rounded-2xl" />
          <Skeleton className="h-20 w-full rounded-2xl" />
          <Skeleton className="h-32 w-full rounded-2xl" />
        </div>
      );
    default:
      return null;
  }
}
