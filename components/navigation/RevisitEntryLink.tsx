"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";

import {
  markRevisitNavigation,
  revisitSourceFromPath,
  type RevisitSource,
} from "@/lib/refinement/revisit-experience";
import {
  trackOldEntryOpenedFromNote,
  trackResurfacedMemoryClicked,
} from "@/lib/retention/retention-loops";

export function RevisitEntryLink({
  entryId,
  source,
  noteId,
  noteText,
  linkRole = "target",
  className,
  children,
}: {
  entryId: string;
  source?: RevisitSource;
  noteId?: string;
  noteText?: string;
  linkRole?: "target" | "past";
  className?: string;
  children: ReactNode;
}) {
  const pathname = usePathname();

  return (
    <Link
      href={`/entry/${entryId}`}
      className={className}
      onClick={() => {
        const resolvedSource = source ?? revisitSourceFromPath(pathname) ?? "memory_note";
        markRevisitNavigation(entryId, resolvedSource);
        if (noteId) {
          if (linkRole === "past") {
            trackOldEntryOpenedFromNote({
              noteId,
              noteText,
              pastEntryId: entryId,
              source: resolvedSource,
            });
          } else {
            trackResurfacedMemoryClicked({
              noteId,
              noteText,
              targetEntryId: entryId,
              source: resolvedSource,
            });
          }
        }
      }}
    >
      {children}
    </Link>
  );
}
