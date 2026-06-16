"use client";

import type { ReactNode } from "react";

import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { cn } from "@/lib/utils";

type ArchiveEmptyStateProps = {
  title: string;
  body?: string;
  action?: ReactNode;
  className?: string;
  testId?: string;
};

/**
 * Intentional archive empty — fades in, no dashed generic placeholders.
 */
export function ArchiveEmptyState({
  title,
  body,
  action,
  className,
  testId = "archive-empty-state",
}: ArchiveEmptyStateProps) {
  return (
    <div
      data-testid={testId}
      className={cn(
        "rounded-2xl border border-dashed border-white/10 bg-black/20 px-4 py-8 text-center",
        className,
      )}
    >
      <p className={ARCHIVE_TYPO.cardTitle}>{title}</p>
      {body ? (
        <p className={cn(ARCHIVE_TYPO.body, "mt-2 mx-auto max-w-md")}>{body}</p>
      ) : null}
      {action ? <div className="mt-4 flex justify-center">{action}</div> : null}
    </div>
  );
}
