"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { Share2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { buildInsightShareCard } from "@/lib/sharing/insight-share-card-builder";
import {
  exportInsightShareCardPng,
  renderInsightShareCardCanvas,
  shareInsightShareCard,
} from "@/lib/sharing/insight-share-card-export";
import { analyzeWeeklyIntelligence } from "@/lib/weekly-intelligence";
import type { InsightShareCardModel } from "@/types/insight-share";

type InsightShareCardExporterProps = {
  className?: string;
};

/** Weekly reflection pattern snapshot — PII-safe PNG + native share sheet. */
export function InsightShareCardExporter({ className = "" }: InsightShareCardExporterProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const card = useMemo<InsightShareCardModel | null>(() => {
    const report = analyzeWeeklyIntelligence();
    return buildInsightShareCard(report);
  }, []);

  useEffect(() => {
    if (!card) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rendered = renderInsightShareCardCanvas(card);
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    canvas.width = rendered.width;
    canvas.height = rendered.height;
    ctx.drawImage(rendered, 0, 0);
  }, [card]);

  if (!card) return null;

  const handleShare = async () => {
    setBusy(true);
    setError(null);
    try {
      await shareInsightShareCard(card);
    } catch (shareError) {
      if (shareError instanceof DOMException && shareError.name === "AbortError") {
        return;
      }
      setError(shareError instanceof Error ? shareError.message : "Share failed.");
    } finally {
      setBusy(false);
    }
  };

  const handleDownload = async () => {
    setBusy(true);
    setError(null);
    try {
      const blob = await exportInsightShareCardPng(card);
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement("a");
      anchor.href = url;
      anchor.download = `archiveme-weekly-insight-${card.id}.png`;
      anchor.click();
      URL.revokeObjectURL(url);
    } catch (downloadError) {
      setError(downloadError instanceof Error ? downloadError.message : "Export failed.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <section
      className={`space-y-3 rounded-2xl border border-violet-500/20 bg-zinc-950/60 p-4 ${className}`}
      data-testid="insight-share-card-exporter"
    >
      <div>
        <p className="text-xs uppercase tracking-[0.18em] text-violet-300/80">
          Share insight
        </p>
        <h2 className="mt-1 text-base font-medium text-zinc-100">{card.headline}</h2>
        <p className="mt-1 text-sm text-zinc-500">{card.weekRangeLabel}</p>
      </div>

      <div className="overflow-hidden rounded-xl border border-white/10 bg-black/30">
        <canvas
          ref={canvasRef}
          className="mx-auto block h-auto w-full max-w-xs"
          aria-label={`Weekly insight share card for ${card.weekRangeLabel}`}
        />
      </div>

      <ul className="space-y-1 text-sm text-zinc-400">
        {card.patternLines.map((line) => (
          <li key={line}>• {line}</li>
        ))}
      </ul>
      <p className="text-xs text-zinc-600">
        Personal details are removed automatically. Referral attribution is embedded in the PNG
        metadata.
      </p>

      <div className="flex flex-wrap gap-2">
        <Button
          type="button"
          size="sm"
          className="mobile-touch-target min-h-11"
          disabled={busy}
          onClick={() => void handleShare()}
        >
          <Share2 className="h-4 w-4" />
          Share snapshot
        </Button>
        <Button
          type="button"
          size="sm"
          variant="secondary"
          className="mobile-touch-target min-h-11"
          disabled={busy}
          onClick={() => void handleDownload()}
        >
          Save PNG
        </Button>
      </div>

      {error ? (
        <p className="text-sm text-red-300" role="alert">
          {error}
        </p>
      ) : null}
    </section>
  );
}
