"use client";

import { VOICEMEMORY_ARCHIVE_POSITIONING } from "@/lib/product/archive-positioning";
import { cn } from "@/lib/utils";

type ArchiveIdentityBarProps = {
  className?: string;
};

export function ArchiveIdentityBar({ className = "" }: ArchiveIdentityBarProps) {
  return (
    <p
      className={cn(
        "text-center text-xs leading-relaxed text-zinc-500 sm:text-sm",
        className,
      )}
      data-testid="archive-identity-bar"
    >
      {VOICEMEMORY_ARCHIVE_POSITIONING}
    </p>
  );
}
