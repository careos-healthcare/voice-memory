"use client";

import { useCallback, useMemo, useState } from "react";
import { Check, Copy } from "lucide-react";

import { Button } from "@/components/ui/button";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import { trackCopiedMemoryMoment } from "@/lib/retention/retention-loops";
import { trackCopyAfterCallback } from "@/lib/retention/pause-moments";
import {
  buildEntrySharedMemoryMoment,
  buildMilestoneSharedMemoryMoment,
} from "@/lib/memory/shared-moments";
import type { EmotionalMilestone } from "@/types/emotional-milestone";
import type { JournalEntry } from "@/types/journal";

type CopyMemoryMomentButtonProps = {
  allEntries: JournalEntry[];
  className?: string;
  onCopied?: () => void;
} & (
  | { source: "entry"; entry: JournalEntry }
  | { source: "milestone"; milestone: EmotionalMilestone }
);

async function writeClipboard(text: string): Promise<void> {
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand("copy");
    document.body.removeChild(textarea);
  }
}

export function CopyMemoryMomentButton(props: CopyMemoryMomentButtonProps) {
  const { allEntries, className } = props;
  const [includeQuote, setIncludeQuote] = useState(false);
  const [copied, setCopied] = useState(false);

  const hasQuote = useMemo(() => {
    if (props.source === "entry") {
      return Boolean(
        props.entry.reflection.exactLanguagePattern?.trim() ||
          props.entry.transcript?.trim(),
      );
    }
    const id = props.milestone.entryId ?? props.milestone.pastEntryId;
    const entry = id ? allEntries.find((item) => item.id === id) : undefined;
    return Boolean(
      entry?.reflection.exactLanguagePattern?.trim() || entry?.transcript?.trim(),
    );
  }, [allEntries, props]);

  const momentText = useMemo(() => {
    if (props.source === "entry") {
      return buildEntrySharedMemoryMoment(props.entry, allEntries, { includeQuote });
    }
    return buildMilestoneSharedMemoryMoment(props.milestone, allEntries, { includeQuote });
  }, [allEntries, includeQuote, props]);

  const sourceId =
    props.source === "entry" ? props.entry.id : props.milestone.id;

  const copyMoment = useCallback(async () => {
    await writeClipboard(momentText);
    trackLaunchEvent(LAUNCH_EVENTS.memoryMomentCopied, {
      source: props.source,
      sourceId,
      includeQuote: String(includeQuote),
    });
    trackCopiedMemoryMoment({
      sourceId,
      source: props.source,
      entryId: props.source === "entry" ? props.entry.id : undefined,
    });
    trackCopyAfterCallback(undefined, sourceId, "entry");
    setCopied(true);
    props.onCopied?.();
    window.setTimeout(() => setCopied(false), 2000);
  }, [momentText, props, sourceId, includeQuote]);

  return (
    <div className={`flex flex-wrap items-center gap-x-4 gap-y-2 ${className ?? ""}`}>
      {hasQuote ? (
        <label className="flex cursor-pointer items-center gap-2 text-xs text-zinc-600">
          <input
            type="checkbox"
            checked={includeQuote}
            onChange={(event) => setIncludeQuote(event.target.checked)}
            className="rounded border-white/15 bg-zinc-900"
          />
          Include quote
        </label>
      ) : null}
      <Button
        type="button"
        variant="ghost"
        size="sm"
        className="h-auto gap-1.5 px-2 py-1.5 text-xs text-zinc-600 hover:text-zinc-400"
        onClick={() => void copyMoment()}
      >
        {copied ? (
          <>
            <Check className="h-3.5 w-3.5" />
            Copied
          </>
        ) : (
          <>
            <Copy className="h-3.5 w-3.5" />
            Copy this moment
          </>
        )}
      </Button>
    </div>
  );
}
