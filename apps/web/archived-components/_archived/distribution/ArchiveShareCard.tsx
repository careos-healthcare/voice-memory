"use client";

import { useEffect, useRef, useState } from "react";

import { Button } from "@/archived-components/_archived/ui/button";
import {
  exportArchiveShareCardPng,
  renderArchiveShareCardCanvas,
} from "@/lib/distribution/archive-share-card-export";
import {
  trackDistributionShareCopied,
  trackDistributionShareExported,
  trackDistributionShareShown,
} from "@/lib/distribution/distribution-events";
import type { ArchiveShareCardModel } from "@/types/distribution";

type ArchiveShareCardProps = {
  card: ArchiveShareCardModel;
  className?: string;
};

/** Screenshot-optimized share card — no private reflection content. */
export function ArchiveShareCard({ card, className = "" }: ArchiveShareCardProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    trackDistributionShareShown({
      momentType: card.momentType,
      variant: card.variant,
    });
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rendered = renderArchiveShareCardCanvas(card);
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    canvas.width = rendered.width;
    canvas.height = rendered.height;
    ctx.drawImage(rendered, 0, 0);
  }, [card]);

  const copyLine = async () => {
    if (typeof navigator === "undefined" || !navigator.clipboard) return;
    await navigator.clipboard.writeText(card.line);
    trackDistributionShareCopied({ momentType: card.momentType });
  };

  const downloadPng = async () => {
    setBusy(true);
    try {
      const blob = await exportArchiveShareCardPng(card);
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement("a");
      anchor.href = url;
      anchor.download = `archiveme-archive-${card.variant}.png`;
      anchor.click();
      URL.revokeObjectURL(url);
      trackDistributionShareExported({ momentType: card.momentType });
    } finally {
      setBusy(false);
    }
  };

  const nativeShare = async () => {
    if (typeof navigator === "undefined" || !navigator.share) {
      await copyLine();
      return;
    }
    try {
      await navigator.share({
        title: "ArchiveMe",
        text: card.line,
        url: window.location.origin,
      });
      trackDistributionShareCopied({ momentType: card.momentType });
    } catch {
      /* cancelled */
    }
  };

  return (
    <div
      className={`space-y-3 ${className}`}
      data-testid="archive-share-card"
      data-share-variant={card.variant}
    >
      <div className="overflow-hidden rounded-2xl border border-violet-500/25 bg-zinc-950 shadow-lg shadow-violet-950/30">
        <canvas
          ref={canvasRef}
          className="block h-auto w-full max-w-sm mx-auto"
          aria-label={`Share card: ${card.line}`}
        />
      </div>
      <div className="flex flex-wrap gap-2">
        <Button type="button" size="sm" variant="secondary" onClick={() => void nativeShare()}>
          Share
        </Button>
        <Button type="button" size="sm" variant="ghost" onClick={() => void copyLine()}>
          Copy line
        </Button>
        <Button
          type="button"
          size="sm"
          variant="ghost"
          disabled={busy}
          onClick={() => void downloadPng()}
        >
          Save screenshot
        </Button>
      </div>
    </div>
  );
}
