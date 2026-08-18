"use client";

import { useCallback, useMemo, useState } from "react";
import { RefreshCw } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  buildArchivePrompts,
  pickArchiveDisplayPrompts,
} from "@/lib/archive/archive-prompt-engine";
import { LOW_EFFORT_MODE_BUTTON, LOW_EFFORT_REFRESH_LABEL } from "@/lib/archive/archive-record-copy";
import {
  trackArchivePromptRefreshed,
  trackArchivePromptSelected,
  trackArchivePromptShown,
} from "@/lib/metrics/archive-prompt-events";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { cn } from "@/lib/utils";
import type { ArchivePrompt } from "@/types/archive-prompt";
import type { JournalEntry } from "@/types/journal";

type LowEffortModeProps = {
  entriesOverride?: JournalEntry[];
  surface?: string;
  className?: string;
  onSelectPrompt: (prompt: ArchivePrompt) => void;
};

export function LowEffortMode({
  entriesOverride,
  surface = "record",
  className = "",
  onSelectPrompt,
}: LowEffortModeProps) {
  const [expanded, setExpanded] = useState(false);
  const [refreshIndex, setRefreshIndex] = useState(0);

  const promptSet = useMemo(
    () => buildArchivePrompts(entriesOverride),
    [entriesOverride],
  );

  const visible = useMemo(
    () => pickArchiveDisplayPrompts(promptSet, { refreshIndex }),
    [promptSet, refreshIndex],
  );

  const open = useCallback(() => {
    setExpanded(true);
    trackArchivePromptShown({
      mode: promptSet.mode,
      promptIds: visible.map((p) => p.id).join(","),
      surface,
    });
  }, [promptSet.mode, surface, visible]);

  const refresh = useCallback(() => {
    const next = refreshIndex + 1;
    setRefreshIndex(next);
    trackArchivePromptRefreshed({
      mode: promptSet.mode,
      surface,
      refreshIndex: String(next),
    });
  }, [promptSet.mode, refreshIndex, surface]);

  const select = useCallback(
    (prompt: ArchivePrompt) => {
      trackArchivePromptSelected({
        promptId: prompt.id,
        type: prompt.type,
        surface,
      });
      onSelectPrompt(prompt);
      setExpanded(false);
    },
    [onSelectPrompt, surface],
  );

  if (!expanded) {
    return (
      <button
        type="button"
        data-testid="low-effort-mode-trigger"
        onClick={open}
        className={cn(
          "text-sm text-violet-300/90 underline-offset-4 hover:text-violet-200 hover:underline",
          className,
        )}
      >
        {LOW_EFFORT_MODE_BUTTON}
      </button>
    );
  }

  return (
    <div
      className={cn("w-full max-w-md space-y-3", className)}
      data-testid="low-effort-mode"
    >
      <div className="flex flex-wrap gap-2" role="group" aria-label="Conversation starters">
        {visible.map((prompt) => (
          <button
            key={prompt.id}
            type="button"
            data-testid={`archive-prompt-chip-${prompt.type}`}
            onClick={() => select(prompt)}
            className="rounded-full border border-violet-500/30 bg-violet-500/10 px-3 py-2 text-left text-xs leading-snug text-zinc-200 hover:border-violet-400/50 hover:bg-violet-500/20"
          >
            {prompt.text}
          </button>
        ))}
      </div>
      <div className="flex items-center gap-3">
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="h-8 gap-1.5 text-xs text-zinc-500"
          data-testid="low-effort-refresh"
          onClick={refresh}
        >
          <RefreshCw className="h-3.5 w-3.5" />
          {LOW_EFFORT_REFRESH_LABEL}
        </Button>
        <button
          type="button"
          onClick={() => setExpanded(false)}
          className="text-xs text-zinc-600 hover:text-zinc-400"
        >
          Hide
        </button>
      </div>
    </div>
  );
}

/** Hook-friendly helper when entries are not passed. */
export function useArchivePromptSet(entriesOverride?: JournalEntry[]) {
  return useMemo(
    () => buildArchivePrompts(entriesOverride ?? getMemoryEligibleEntries()),
    [entriesOverride],
  );
}
