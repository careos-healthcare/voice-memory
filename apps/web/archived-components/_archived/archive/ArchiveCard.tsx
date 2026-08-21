"use client";

import type { ReactNode } from "react";

import { ArchiveTransition } from "@/archived-components/_archived/archive/ArchiveTransition";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { cn } from "@/lib/utils";

export type ArchiveCardVariant = "PRIMARY" | "SECONDARY" | "SUPPORTING";

const VARIANT_STYLES: Record<ArchiveCardVariant, string> = {
  PRIMARY: "rounded-2xl border border-violet-500/25 bg-violet-950/20 shadow-sm",
  SECONDARY: "rounded-2xl border border-white/10 bg-zinc-900/50",
  SUPPORTING: "rounded-xl border border-white/5 bg-black/20",
};

const VARIANT_GRAVITY: Record<ArchiveCardVariant, string> = {
  PRIMARY: "belief",
  SECONDARY: "evidence",
  SUPPORTING: "utilities",
};

type ArchiveCardProps = {
  variant: ArchiveCardVariant;
  title?: string;
  children: ReactNode;
  className?: string;
  testId?: string;
  footer?: ReactNode;
};

export function ArchiveCard({
  variant,
  title,
  children,
  className,
  testId,
  footer,
}: ArchiveCardProps) {
  return (
    <ArchiveTransition mode="card">
      <section
        className={cn(VARIANT_STYLES[variant], "px-4 py-4", className)}
        data-archive-card={variant.toLowerCase()}
        data-gravity={VARIANT_GRAVITY[variant]}
        data-testid={testId}
      >
        {title ? <h2 className={ARCHIVE_TYPO.cardTitle}>{title}</h2> : null}
        <div className={title ? "mt-3" : undefined}>{children}</div>
        {footer ? <div className="mt-4 border-t border-white/5 pt-3">{footer}</div> : null}
      </section>
    </ArchiveTransition>
  );
}
