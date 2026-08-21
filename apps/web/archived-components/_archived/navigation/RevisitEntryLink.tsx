"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";

import { recordMemoryLineClicked } from "@/lib/sync/cross-device-continuity";
import {
  markRevisitNavigation,
  revisitSourceFromPath,
  type RevisitSource,
} from "@/lib/refinement/revisit-experience";
import {
  trackOldEntryOpenedFromNote,
  trackResurfacedMemoryClicked,
} from "@/lib/retention/retention-loops";
import { recordSilenceNoteAction } from "@/lib/refinement/silence-calibration";
import { trackOldEntryRevisitAfterCallback as trackPauseOldEntryRevisit } from "@/lib/retention/pause-moments";
import {
  trackFirstSessionOldReflectionOpened,
} from "@/lib/marketing/first-session-comprehension";
import { observeMagicCandidateOpened } from "@/lib/retention/first-magic-moment";
import {
  observeCallbackOpened,
  observeCallbackReread,
} from "@/lib/revisit/callback-learning";

export function RevisitEntryLink({
  entryId,
  source,
  noteId,
  noteText,
  linkRole = "target",
  className,
  onNavigate,
  children,
}: {
  entryId: string;
  source?: RevisitSource;
  noteId?: string;
  noteText?: string;
  linkRole?: "target" | "past";
  className?: string;
  onNavigate?: () => void;
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
        if (linkRole === "past" || noteId) {
          trackFirstSessionOldReflectionOpened(entryId, resolvedSource);
        }
        if (noteId) {
          observeMagicCandidateOpened(noteId, {
            entryId,
            source: resolvedSource,
          });
          observeCallbackOpened(
            { id: noteId, entryId },
            undefined,
            { source: resolvedSource, linkRole },
          );
          if (linkRole === "past") {
            observeCallbackReread({ id: noteId, entryId: entryId, pastEntryId: entryId });
          }
          recordMemoryLineClicked({
            noteId,
            noteText,
            entryId,
          });
          recordSilenceNoteAction(noteId);
          if (linkRole === "past") {
            trackOldEntryOpenedFromNote({
              noteId,
              noteText,
              pastEntryId: entryId,
              source: resolvedSource,
            });
            trackPauseOldEntryRevisit(noteId, entryId, resolvedSource);
          } else {
            trackResurfacedMemoryClicked({
              noteId,
              noteText,
              targetEntryId: entryId,
              source: resolvedSource,
            });
          }
        }
        onNavigate?.();
      }}
    >
      {children}
    </Link>
  );
}
