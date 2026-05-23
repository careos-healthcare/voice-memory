"use client";

import { cn } from "@/lib/utils";

/** Optional wrapper for a very subtle opacity rhythm — calm, not gamified. */
export function MemoryBreathing({
  children,
  className,
  enabled = true,
}: {
  children: React.ReactNode;
  className?: string;
  enabled?: boolean;
}) {
  return (
    <div className={cn(enabled ? "memory-breathe" : undefined, className)}>
      {children}
    </div>
  );
}
