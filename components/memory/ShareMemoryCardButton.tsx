"use client";

import { useCallback, useMemo, useState } from "react";
import { Check, Copy } from "lucide-react";

import { Button } from "@/components/ui/button";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import {
  buildShareCardText,
  type ShareMemoryCardKind,
} from "@/lib/share-memory-cards";
import type { JournalEntry } from "@/types/journal";

const CARD_LABELS: Record<ShareMemoryCardKind, string> = {
  weekly_summary: "Weekly summary",
  timeline_compression: "Timeline compression",
  memory_continuity: "Memory continuity",
  dominant_theme: "Dominant theme",
  entry_observation: "Concrete observation",
};

interface ShareMemoryCardButtonProps {
  kind: ShareMemoryCardKind;
  entry?: JournalEntry;
  /** Show optional transcript toggle (entry cards always can; aggregate cards use latest entry). */
  allowTranscriptExcerpt?: boolean;
  className?: string;
}

export function ShareMemoryCardButton({
  kind,
  entry,
  allowTranscriptExcerpt = true,
  className,
}: ShareMemoryCardButtonProps) {
  const [includeTranscript, setIncludeTranscript] = useState(false);
  const [copied, setCopied] = useState(false);

  const cardText = useMemo(
    () => buildShareCardText(kind, { includeTranscript, entry }),
    [kind, includeTranscript, entry],
  );

  const copyCard = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(cardText);
      trackLaunchEvent(LAUNCH_EVENTS.shareCardCopied, {
        kind,
        includeTranscript: String(includeTranscript),
      });
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2000);
    } catch {
      // Fallback for older browsers
      const textarea = document.createElement("textarea");
      textarea.value = cardText;
      textarea.style.position = "fixed";
      textarea.style.opacity = "0";
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand("copy");
      document.body.removeChild(textarea);
      trackLaunchEvent(LAUNCH_EVENTS.shareCardCopied, {
        kind,
        includeTranscript: String(includeTranscript),
      });
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2000);
    }
  }, [cardText, kind, includeTranscript]);

  const showTranscriptToggle =
    allowTranscriptExcerpt && (kind === "entry_observation" ? Boolean(entry?.transcript?.trim()) : true);

  return (
    <div
      className={`rounded-2xl border border-white/10 bg-white/[0.02] p-4 ${className ?? ""}`}
      data-share-card-kind={kind}
    >
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-zinc-500">
            Share memory moment
          </p>
          <p className="mt-1 text-sm font-medium text-white">{CARD_LABELS[kind]}</p>
        </div>
        <Button type="button" variant="secondary" size="sm" onClick={() => void copyCard()}>
          {copied ? (
            <>
              <Check className="h-4 w-4" />
              Copied
            </>
          ) : (
            <>
              <Copy className="h-4 w-4" />
              Copy text
            </>
          )}
        </Button>
      </div>

      {showTranscriptToggle ? (
        <label className="mt-3 flex cursor-pointer items-center gap-2 text-xs text-zinc-400">
          <input
            type="checkbox"
            checked={includeTranscript}
            onChange={(e) => setIncludeTranscript(e.target.checked)}
            className="rounded border-white/20 bg-zinc-900"
          />
          Include transcript excerpt (off by default)
        </label>
      ) : null}

      <pre className="mt-3 max-h-40 overflow-y-auto whitespace-pre-wrap rounded-xl border border-white/5 bg-black/30 p-3 font-sans text-xs leading-relaxed text-zinc-300">
        {cardText}
      </pre>
    </div>
  );
}

export function ShareMemoryCardRow({
  kinds,
  entry,
}: {
  kinds: ShareMemoryCardKind[];
  entry?: JournalEntry;
}) {
  return (
    <div className="space-y-3">
      {kinds.map((kind) => (
        <ShareMemoryCardButton key={kind} kind={kind} entry={entry} />
      ))}
    </div>
  );
}
