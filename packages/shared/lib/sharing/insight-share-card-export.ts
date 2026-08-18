import type { InsightShareCardModel } from "@/types/insight-share";

import { embedPngTextMetadata } from "./png-text-metadata";

const WIDTH = 1080;
const HEIGHT = 1350;
const BACKGROUND = "#09090b";
const ACCENT = "#a78bfa";
const LINE_COLOR = "#f4f4f5";
const MUTED = "#71717a";

function wrapText(
  ctx: CanvasRenderingContext2D,
  text: string,
  maxWidth: number,
): string[] {
  const words = text.split(/\s+/);
  const lines: string[] = [];
  let current = "";
  for (const word of words) {
    const next = current ? `${current} ${word}` : word;
    if (ctx.measureText(next).width <= maxWidth) {
      current = next;
    } else {
      if (current) lines.push(current);
      current = word;
    }
  }
  if (current) lines.push(current);
  return lines.length > 0 ? lines : [text];
}

export function renderInsightShareCardCanvas(
  card: InsightShareCardModel,
): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  canvas.width = WIDTH;
  canvas.height = HEIGHT;
  const ctx = canvas.getContext("2d");
  if (!ctx) return canvas;

  ctx.fillStyle = BACKGROUND;
  ctx.fillRect(0, 0, WIDTH, HEIGHT);

  ctx.strokeStyle = `${ACCENT}33`;
  ctx.lineWidth = 2;
  ctx.strokeRect(48, 48, WIDTH - 96, HEIGHT - 96);

  ctx.font = "600 13px system-ui, -apple-system, sans-serif";
  ctx.fillStyle = ACCENT;
  ctx.textAlign = "center";
  ctx.fillText(card.footer, WIDTH / 2, 120);

  ctx.font = "600 34px Georgia, 'Times New Roman', serif";
  ctx.fillStyle = LINE_COLOR;
  ctx.fillText(card.headline, WIDTH / 2, 210);

  ctx.font = "400 16px system-ui, -apple-system, sans-serif";
  ctx.fillStyle = MUTED;
  ctx.fillText(card.weekRangeLabel, WIDTH / 2, 252);

  ctx.textAlign = "left";
  ctx.font = "400 28px system-ui, -apple-system, sans-serif";
  ctx.fillStyle = LINE_COLOR;

  let y = 340;
  const maxWidth = WIDTH - 160;
  for (const line of card.patternLines) {
    const wrapped = wrapText(ctx, `• ${line}`, maxWidth);
    for (const part of wrapped) {
      ctx.fillText(part, 80, y);
      y += 42;
    }
    y += 8;
  }

  ctx.textAlign = "center";
  ctx.font = "400 12px system-ui, -apple-system, sans-serif";
  ctx.fillStyle = MUTED;
  ctx.fillText("Patterns only — no private journal text", WIDTH / 2, HEIGHT - 120);

  return canvas;
}

export async function exportInsightShareCardPng(
  card: InsightShareCardModel,
): Promise<Blob> {
  const canvas = renderInsightShareCardCanvas(card);
  const rawBlob = await new Promise<Blob>((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (blob) resolve(blob);
        else reject(new Error("Failed to export insight share card"));
      },
      "image/png",
      1,
    );
  });

  const rawBytes = new Uint8Array(await rawBlob.arrayBuffer());
  const withMetadata = embedPngTextMetadata(rawBytes, {
    ArchiveMeReferral: card.referralLink,
    ArchiveMeSource: card.referralSource,
  });

  return new Blob([new Uint8Array(withMetadata)], { type: "image/png" });
}

export async function shareInsightShareCard(card: InsightShareCardModel): Promise<void> {
  const blob = await exportInsightShareCardPng(card);
  const file = new File([blob], `archiveme-weekly-insight-${card.id}.png`, {
    type: "image/png",
  });

  if (
    typeof navigator !== "undefined" &&
    typeof navigator.share === "function" &&
    (!navigator.canShare || navigator.canShare({ files: [file] }))
  ) {
    await navigator.share({
      title: card.footer,
      text: card.plainTextShare,
      files: [file],
    });
    return;
  }

  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = file.name;
  anchor.click();
  URL.revokeObjectURL(url);
}
