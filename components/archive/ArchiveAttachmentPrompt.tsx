"use client";

import { useCallback, useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  ARCHIVE_ATTACHMENT_DISMISS,
  ARCHIVE_ATTACHMENT_LEVEL_LABELS,
  ARCHIVE_ATTACHMENT_QUESTION,
  ARCHIVE_MOAT_PERCEPTION_LABELS,
  ARCHIVE_MOAT_PERCEPTION_QUESTION,
  ARCHIVE_ATTACHMENT_REASON_LABELS,
  ARCHIVE_ATTACHMENT_REASON_QUESTION,
} from "@/lib/archive/archive-attachment-copy";
import {
  canShowArchiveAttachmentPrompt,
  dismissArchiveAttachmentPrompt,
  dismissArchiveAttachmentReasonPrompt,
  dismissArchiveMoatPerceptionPrompt,
  saveArchiveAttachmentLevel,
  saveArchiveAttachmentReason,
  saveArchiveMoatPerception,
  shouldShowArchiveAttachmentReasonPrompt,
  shouldShowArchiveMoatPerceptionPrompt,
} from "@/lib/archive/archive-attachment";
import {
  ARCHIVE_ATTACHMENT_LEVEL_IDS,
  ARCHIVE_ATTACHMENT_REASON_IDS,
  ARCHIVE_MOAT_PERCEPTION_IDS,
  type ArchiveAttachmentLevelId,
  type ArchiveAttachmentReasonId,
  type ArchiveMoatPerceptionId,
} from "@/types/archive-attachment";
import type { JournalEntry } from "@/types/journal";

type Phase = "level" | "reason" | "moat" | null;

interface ArchiveAttachmentPromptProps {
  className?: string;
  entriesOverride?: JournalEntry[];
}

export function ArchiveAttachmentPrompt({
  className = "",
  entriesOverride,
}: ArchiveAttachmentPromptProps) {
  const [phase, setPhase] = useState<Phase>(null);
  const [reasonContext, setReasonContext] = useState<ReturnType<
    typeof shouldShowArchiveAttachmentReasonPrompt
  >>(null);
  const [moatContext, setMoatContext] = useState<ReturnType<
    typeof shouldShowArchiveMoatPerceptionPrompt
  >>(null);

  const refresh = useCallback(() => {
    const pendingMoat = shouldShowArchiveMoatPerceptionPrompt();
    if (pendingMoat) {
      setMoatContext(pendingMoat);
      setPhase("moat");
      return;
    }
    const pendingReason = shouldShowArchiveAttachmentReasonPrompt();
    if (pendingReason) {
      setReasonContext(pendingReason);
      setPhase("reason");
      return;
    }
    if (canShowArchiveAttachmentPrompt(Date.now(), entriesOverride)) {
      setPhase("level");
      return;
    }
    setPhase(null);
  }, [entriesOverride]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  if (!phase) return null;

  if (phase === "moat" && moatContext) {
    return (
      <Card
        className={`border-violet-500/25 bg-violet-950/15 ${className}`}
        data-testid="archive-moat-perception-prompt"
      >
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-medium text-violet-100/90">
            {ARCHIVE_MOAT_PERCEPTION_QUESTION}
          </CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-2">
          {ARCHIVE_MOAT_PERCEPTION_IDS.map((id) => (
            <Button
              key={id}
              type="button"
              size="sm"
              variant="secondary"
              className="h-auto justify-start py-2 text-left"
              onClick={() => {
                saveArchiveMoatPerception(id, moatContext);
                setPhase(null);
                setMoatContext(null);
              }}
            >
              {ARCHIVE_MOAT_PERCEPTION_LABELS[id]}
            </Button>
          ))}
          <button
            type="button"
            onClick={() => {
              dismissArchiveMoatPerceptionPrompt();
              setPhase(null);
              setMoatContext(null);
            }}
            className="mt-1 text-xs text-zinc-600 hover:text-zinc-400"
          >
            {ARCHIVE_ATTACHMENT_DISMISS}
          </button>
        </CardContent>
      </Card>
    );
  }

  if (phase === "reason" && reasonContext) {
    return (
      <Card
        className={`border-rose-500/25 bg-rose-950/15 ${className}`}
        data-testid="archive-attachment-reason-prompt"
      >
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-medium text-rose-100/90">
            {ARCHIVE_ATTACHMENT_REASON_QUESTION}
          </CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-2">
          {ARCHIVE_ATTACHMENT_REASON_IDS.map((id) => (
            <Button
              key={id}
              type="button"
              size="sm"
              variant="secondary"
              className="h-auto justify-start whitespace-normal py-2 text-left"
              onClick={() => {
                saveArchiveAttachmentReason(id, reasonContext);
                const moat = shouldShowArchiveMoatPerceptionPrompt();
                if (moat) {
                  setMoatContext(moat);
                  setReasonContext(null);
                  setPhase("moat");
                  return;
                }
                setPhase(null);
                setReasonContext(null);
              }}
            >
              {ARCHIVE_ATTACHMENT_REASON_LABELS[id]}
            </Button>
          ))}
          <button
            type="button"
            onClick={() => {
              dismissArchiveAttachmentReasonPrompt();
              setPhase(null);
              setReasonContext(null);
            }}
            className="mt-1 text-xs text-zinc-600 hover:text-zinc-400"
          >
            {ARCHIVE_ATTACHMENT_DISMISS}
          </button>
        </CardContent>
      </Card>
    );
  }

  const submitLevel = (level: ArchiveAttachmentLevelId) => {
    saveArchiveAttachmentLevel(level, entriesOverride);
    if (level === "very" || level === "extremely") {
      const ctx = shouldShowArchiveAttachmentReasonPrompt();
      if (ctx) {
        setReasonContext(ctx);
        setPhase("reason");
        return;
      }
    }
    const moat = shouldShowArchiveMoatPerceptionPrompt();
    if (moat) {
      setMoatContext(moat);
      setPhase("moat");
      return;
    }
    setPhase(null);
  };

  const dismiss = () => {
    dismissArchiveAttachmentPrompt();
    setPhase(null);
  };

  return (
    <Card
      className={`border-rose-500/30 bg-rose-950/10 ${className}`}
      data-testid="archive-attachment-prompt"
    >
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-rose-100/90">
          {ARCHIVE_ATTACHMENT_QUESTION}
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {ARCHIVE_ATTACHMENT_LEVEL_IDS.map((id) => (
          <Button
            key={id}
            type="button"
            size="sm"
            variant="secondary"
            className="h-auto justify-start py-2 text-left"
            onClick={() => submitLevel(id)}
          >
            {ARCHIVE_ATTACHMENT_LEVEL_LABELS[id]}
          </Button>
        ))}
        <button
          type="button"
          onClick={dismiss}
          className="mt-1 text-xs text-zinc-600 hover:text-zinc-400"
        >
          {ARCHIVE_ATTACHMENT_DISMISS}
        </button>
      </CardContent>
    </Card>
  );
}
