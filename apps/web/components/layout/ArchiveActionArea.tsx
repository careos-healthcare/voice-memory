"use client";

import Link from "next/link";
import type { ReactNode } from "react";

import { ARCHIVE_SPACE } from "@/lib/design/archive-spacing";
import { cn } from "@/lib/utils";

export type ArchiveActionDescriptor = {
  label: string;
  href?: string;
  onClick?: () => void;
  disabled?: boolean;
  testId?: string;
};

type ArchiveActionAreaProps = {
  primary?: ArchiveActionDescriptor;
  secondary?: ArchiveActionDescriptor;
  children?: ReactNode;
  className?: string;
};

function ActionButton({ action, variant }: { action: ArchiveActionDescriptor; variant: "primary" | "secondary" }) {
  const base =
    variant === "primary"
      ? "inline-flex min-h-10 items-center justify-center rounded-full bg-violet-600/90 px-5 text-sm font-medium text-white hover:bg-violet-600"
      : "inline-flex min-h-10 items-center justify-center rounded-full border border-white/10 px-4 text-sm text-zinc-300 hover:bg-white/5";

  if (action.href) {
    return (
      <Link
        href={action.href}
        className={base}
        data-testid={action.testId}
        aria-disabled={action.disabled}
      >
        {action.label}
      </Link>
    );
  }

  return (
    <button
      type="button"
      className={base}
      onClick={action.onClick}
      disabled={action.disabled}
      data-testid={action.testId}
    >
      {action.label}
    </button>
  );
}

/** Primary CTA bottom-right; secondary below (stacked on narrow viewports). */
export function ArchiveActionArea({
  primary,
  secondary,
  children,
  className,
}: ArchiveActionAreaProps) {
  if (!primary && !secondary && !children) return null;

  return (
    <div
      className={cn(
        "flex flex-col items-stretch sm:flex-row sm:items-end sm:justify-end",
        ARCHIVE_SPACE.gapSm,
        className,
      )}
      data-archive-section="action"
      data-testid="archive-action-area"
    >
      <div className="flex w-full flex-col items-stretch sm:max-w-xs sm:items-end">
        {secondary ? (
          <div className="order-2 sm:order-1 sm:mb-2 sm:w-full sm:text-right">
            <ActionButton action={secondary} variant="secondary" />
          </div>
        ) : null}
        {primary ? (
          <div className="order-1 sm:order-2 sm:ml-auto">
            <ActionButton action={primary} variant="primary" />
          </div>
        ) : null}
        {children}
      </div>
    </div>
  );
}
