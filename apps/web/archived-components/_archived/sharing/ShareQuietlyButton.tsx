"use client";

import { useCallback, useState } from "react";
import { Check, Download, Share2 } from "lucide-react";

import { QuietShareCardPreview } from "@/archived-components/_archived/sharing/QuietShareCard";
import { Button } from "@/archived-components/_archived/ui/button";
import {
  buildQuietShareCardPlainText,
  downloadQuietShareCardPng,
} from "@/lib/sharing/share-card-export";
import { trackQuietShare } from "@/lib/sharing/share-observation";
import type { QuietShareCard } from "@/types/sharing";

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

export function ShareQuietlyButton({
  card,
  copiedBefore,
  className,
}: {
  card: QuietShareCard | null;
  copiedBefore?: boolean;
  className?: string;
}) {
  const [open, setOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const [saved, setSaved] = useState(false);

  const copyText = useCallback(async () => {
    if (!card) return;
    await writeClipboard(buildQuietShareCardPlainText(card));
    trackQuietShare({
      source: card.source,
      sourceId: card.sourceId,
      line: card.line,
      entryId: card.entryId,
      callbackId: card.callbackId,
      copiedBefore,
      format: "text",
    });
    setCopied(true);
    window.setTimeout(() => setCopied(false), 2000);
  }, [card, copiedBefore]);

  const savePng = useCallback(async () => {
    if (!card) return;
    await downloadQuietShareCardPng(card);
    trackQuietShare({
      source: card.source,
      sourceId: card.sourceId,
      line: card.line,
      entryId: card.entryId,
      callbackId: card.callbackId,
      copiedBefore,
      format: "png",
    });
    setSaved(true);
    window.setTimeout(() => setSaved(false), 2000);
  }, [card, copiedBefore]);

  if (!card) return null;

  return (
    <div className={className}>
      <Button
        type="button"
        variant="ghost"
        size="sm"
        className="h-8 px-2 text-xs text-zinc-600 hover:text-zinc-400"
        onClick={() => setOpen((value) => !value)}
      >
        <Share2 className="mr-1.5 h-3.5 w-3.5" />
        Share quietly
      </Button>

      {open ? (
        <div className="mt-3 space-y-3 rounded-xl border border-white/[0.06] bg-zinc-900/40 p-4">
          <QuietShareCardPreview card={card} />
          <div className="flex flex-wrap gap-2">
            <Button type="button" variant="secondary" size="sm" onClick={() => void copyText()}>
              {copied ? <Check className="h-3.5 w-3.5" /> : null}
              Copy text
            </Button>
            <Button type="button" variant="secondary" size="sm" onClick={() => void savePng()}>
              {saved ? <Check className="h-3.5 w-3.5" /> : <Download className="h-3.5 w-3.5" />}
              Save image
            </Button>
          </div>
          <p className="text-xs leading-relaxed text-zinc-600">
            Optional — private by default. No metrics, no feed.
          </p>
        </div>
      ) : null}
    </div>
  );
}
