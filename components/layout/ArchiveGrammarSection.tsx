"use client";

import type { ReactNode } from "react";

import type { ArchiveGrammarSection } from "@/lib/design/archive-page-grammar";
import { cn } from "@/lib/utils";

type ArchiveGrammarSectionProps = {
  section: ArchiveGrammarSection;
  gravity?: string;
  children: ReactNode;
  className?: string;
};

/** Explicit PAGE_STRUCTURE section marker for audit + scan pattern. */
export function ArchiveGrammarSection({
  section,
  gravity,
  children,
  className,
}: ArchiveGrammarSectionProps) {
  if (!children) return null;
  return (
    <section
      data-archive-grammar-section={section}
      data-gravity={gravity ?? section}
      className={cn(className)}
    >
      {children}
    </section>
  );
}
