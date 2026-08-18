"use client";

import { useEffect, useRef } from "react";

import { renderQuietShareCardCanvas } from "@/lib/sharing/share-card-export";
import type { QuietShareCard } from "@/types/sharing";

export function QuietShareCardPreview({ card }: { card: QuietShareCard }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rendered = renderQuietShareCardCanvas(card);
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    canvas.width = rendered.width;
    canvas.height = rendered.height;
    ctx.drawImage(rendered, 0, 0);
  }, [card]);

  return (
    <div className="overflow-hidden rounded-xl border border-white/[0.06] bg-zinc-950">
      <canvas
        ref={canvasRef}
        className="block h-auto w-full max-w-md"
        aria-label={`Share card: ${card.line}`}
      />
    </div>
  );
}
