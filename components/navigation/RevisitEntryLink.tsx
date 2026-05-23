"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";

import {
  markRevisitNavigation,
  revisitSourceFromPath,
  type RevisitSource,
} from "@/lib/refinement/revisit-experience";

export function RevisitEntryLink({
  entryId,
  source,
  className,
  children,
}: {
  entryId: string;
  source?: RevisitSource;
  className?: string;
  children: ReactNode;
}) {
  const pathname = usePathname();

  return (
    <Link
      href={`/entry/${entryId}`}
      className={className}
      onClick={() => {
        markRevisitNavigation(entryId, source ?? revisitSourceFromPath(pathname) ?? "memory_note");
      }}
    >
      {children}
    </Link>
  );
}
